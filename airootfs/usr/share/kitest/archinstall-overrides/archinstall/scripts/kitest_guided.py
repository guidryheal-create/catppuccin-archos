import json
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

from archinstall.default_profiles.profile import GreeterType
from archinstall.lib.applications.application_handler import ApplicationHandler
from archinstall.lib.args import ArchConfig, ArchConfigHandler
from archinstall.lib.authentication.authentication_handler import AuthenticationHandler
from archinstall.lib.configuration import ConfigurationOutput
from archinstall.lib.disk.filesystem import FilesystemHandler
from archinstall.lib.disk.utils import disk_layouts
from archinstall.lib.general.general_menu import PostInstallationAction, select_post_installation
from archinstall.lib.global_menu import GlobalMenu
from archinstall.lib.hardware import GfxDriver
from archinstall.lib.installer import Installer, accessibility_tools_in_use, run_custom_user_commands
from archinstall.lib.menu.util import delayed_warning
from archinstall.lib.mirror.mirror_handler import MirrorListHandler
from archinstall.lib.models import Bootloader
from archinstall.lib.models.application import (
	Audio,
	AudioConfiguration,
	ApplicationConfiguration,
	BluetoothConfiguration,
	Firewall,
	FirewallConfiguration,
	PowerManagement,
	PowerManagementConfiguration,
	PrintServiceConfiguration,
)
from archinstall.lib.models.device import DiskLayoutType, EncryptionType
from archinstall.lib.models.mirrors import CustomRepository, SignCheck, SignOption
from archinstall.lib.models.profile import ProfileConfiguration
from archinstall.lib.models.users import User
from archinstall.lib.network.network_handler import install_network_config
from archinstall.lib.output import debug, error, info, warn
from archinstall.lib.packages.util import check_version_upgrade
from archinstall.lib.pathnames import KITEST_DEFAULT_LOCAL_REPO
from archinstall.lib.profile.profiles_handler import profile_handler
from archinstall.lib.translationhandler import tr
from archinstall.tui.ui.components import tui

KITEST_KERNELS = ['linux-kitten-cachyos-hardened', 'linux']
KITEST_BASE_PACKAGES = [
	'networkmanager',
	'sddm',
	'plasma-meta',
	'plasma-x11-session',
	'kio-extras',
	'dolphin',
	'konsole',
	'kdialog',
	'pipewire',
	'pipewire-alsa',
	'pipewire-pulse',
	'wireplumber',
	'flatpak',
	'git',
	'wget',
	'curl',
	'starship',
	'fastfetch',
]
KITEST_SERVICES = [
	'NetworkManager',
	'sddm',
	'bluetooth',
	'docker',
	'flatpak-system-helper',
]
KITEST_SESSION_COMMANDS = [
	'if [ -x /usr/local/bin/kitest-postinstall.sh ]; then /usr/local/bin/kitest-postinstall.sh; fi',
	'if [ -x /usr/local/bin/kitest-desktop-extras.sh ]; then /usr/local/bin/kitest-desktop-extras.sh; fi',
]


class KitestMenu(GlobalMenu):
	"""Global menu with profile and app entries hidden."""

	def _get_menu_options(self) -> list:  # type: ignore[override]
		options = super()._get_menu_options()
		hidden_keys = {'profile_config', 'app_config'}
		return [item for item in options if item.key not in hidden_keys]


class KitestApplicationHandler(ApplicationHandler):
	"""Ensures flatpak runtime is installed and service-enabled."""

	def install_applications(self, install_session: Installer, app_config: ApplicationConfiguration, users: list[User] | None = None) -> None:
		super().install_applications(install_session, app_config, users)
		install_session.add_additional_packages(['flatpak'])
		install_session.enable_service('flatpak-system-helper')


def _read_raw_config_data(arch_config_handler: ArchConfigHandler) -> dict:
	args = arch_config_handler.args
	if args.config:
		try:
			return json.loads(args.config.read_text())
		except (json.JSONDecodeError, OSError) as err:
			warn(f'Unable to read custom config from {args.config}: {err}')
			return {}

	if args.config_url:
		try:
			with urlopen(args.config_url) as resp:
				return json.loads(resp.read().decode('utf-8'))
		except (HTTPError, URLError, json.JSONDecodeError) as err:
			warn(f'Unable to fetch custom config from {args.config_url}: {err}')

	return {}


def _merge_unique(current: list[str], defaults: list[str]) -> list[str]:
	merged = list(current)
	for item in defaults:
		if item not in merged:
			merged.append(item)
	return merged


def _default_profile_config() -> ProfileConfiguration:
	desktop_profile = profile_handler.get_profile_by_name('Desktop')
	plasma_profile = profile_handler.get_profile_by_name('KDE Plasma')

	if desktop_profile is None or plasma_profile is None:
		raise ValueError('Unable to resolve Desktop/KDE Plasma profiles for Kitest defaults')

	desktop_profile.current_selection = [plasma_profile]
	return ProfileConfiguration(
		profile=desktop_profile,
		gfx_driver=GfxDriver.AllOpenSource,
		greeter=GreeterType.Sddm,
	)


def _default_app_config() -> ApplicationConfiguration:
	return ApplicationConfiguration(
		bluetooth_config=BluetoothConfiguration(enabled=True),
		audio_config=AudioConfiguration(audio=Audio.PIPEWIRE),
		power_management_config=PowerManagementConfiguration(power_management=PowerManagement.POWER_PROFILES_DAEMON),
		print_service_config=PrintServiceConfiguration(enabled=False),
		firewall_config=FirewallConfiguration(firewall=Firewall.FWD),
	)


def apply_kitest_defaults(arch_config_handler: ArchConfigHandler) -> dict:
	config = arch_config_handler.config
	raw_config = _read_raw_config_data(arch_config_handler)

	config.kernels = _merge_unique(config.kernels, KITEST_KERNELS)
	config.packages = _merge_unique(config.packages, KITEST_BASE_PACKAGES)
	config.services = _merge_unique(config.services, KITEST_SERVICES)

	if config.profile_config is None:
		config.profile_config = _default_profile_config()
	if config.app_config is None:
		config.app_config = _default_app_config()

	if config.custom_commands:
		config.custom_commands = _merge_unique(config.custom_commands, KITEST_SESSION_COMMANDS)
	else:
		config.custom_commands = KITEST_SESSION_COMMANDS[:]

	return raw_config


def _enable_local_repo_if_available(installation: Installer, raw_config: dict) -> None:
	repo_cfg = raw_config.get('kitest_local_repo', {})
	if isinstance(repo_cfg, dict):
		enabled = repo_cfg.get('enabled', True)
		name = repo_cfg.get('name', 'kitten-local')
		path = repo_cfg.get('path', KITEST_DEFAULT_LOCAL_REPO)
	else:
		enabled = True
		name = 'kitten-local'
		path = KITEST_DEFAULT_LOCAL_REPO

	if not enabled:
		return

	repo_path = Path(path)
	repo_db = repo_path / f'{name}.db'
	repo_db_tar = repo_path / f'{name}.db.tar.gz'
	if not repo_path.exists() or (not repo_db.exists() and not repo_db_tar.exists()):
		info(f'Kitest local repo not found at {repo_path}; using mirrors only')
		return

	info(f'Enabling local prebuilt repo from {repo_path}')
	repo = CustomRepository(
		name=name,
		url=f'file://{repo_path}',
		sign_check=SignCheck.Optional,
		sign_option=SignOption.TrustAll,
	)

	if not installation.target.exists():
		return

	repo_block = (
		f'[{repo.name}]\n'
		f'Server = {repo.url}\n'
		f'SigLevel = {repo.sign_check.value} {repo.sign_option.value}\n'
	)
	with open(installation.target / 'etc/pacman.conf', 'a') as pacman_conf:
		pacman_conf.write(f'\n{repo_block}\n')


def _run_bootstrap_and_postinstall(installation: Installer, raw_config: dict) -> None:
	installation.genfstab()

	for cmd in ('mount -a', 'pacman-key --init', 'pacman-key --populate archlinux'):
		try:
			installation.arch_chroot(cmd)
		except Exception as err:
			warn(f'Post-install bootstrap command failed ({cmd}): {err}')

	flatpak_cfg = raw_config.get('kitest_flatpak', {})
	if isinstance(flatpak_cfg, dict):
		enable_flatpak = flatpak_cfg.get('enabled', True)
		remote_name = flatpak_cfg.get('remote_name', 'flathub')
		remote_url = flatpak_cfg.get('remote_url', 'https://flathub.org/repo/flathub.flatpakrepo')
		apps = flatpak_cfg.get('apps', [])
	else:
		enable_flatpak = True
		remote_name = 'flathub'
		remote_url = 'https://flathub.org/repo/flathub.flatpakrepo'
		apps = []

	if enable_flatpak:
		try:
			installation.arch_chroot(f'flatpak remote-add --if-not-exists {remote_name} {remote_url}')
		except Exception as err:
			warn(f'Unable to add flatpak remote {remote_name}: {err}')

		if isinstance(apps, list):
			for app in apps:
				try:
					installation.arch_chroot(f'flatpak install -y --system {remote_name} {app}')
				except Exception as err:
					warn(f'Unable to install flatpak app {app}: {err}')

	extra_post = raw_config.get('kitest_postinstall_commands', [])
	if isinstance(extra_post, list):
		for command in extra_post:
			if isinstance(command, str) and command.strip():
				try:
					installation.arch_chroot(command)
				except Exception as err:
					warn(f'Unable to run kitest postinstall command "{command}": {err}')


def show_menu(
	arch_config_handler: ArchConfigHandler,
	mirror_list_handler: MirrorListHandler,
) -> None:
	upgrade = check_version_upgrade()
	title_text = 'Kitest Installer'

	if upgrade:
		text = tr('New version available') + f': {upgrade}'
		title_text += f' ({text})'

	global_menu = KitestMenu(
		arch_config_handler.config,
		mirror_list_handler,
		arch_config_handler.args.skip_boot,
		advanced=arch_config_handler.args.advanced,
		title=title_text,
	)

	result: ArchConfig | None = tui.run(global_menu)
	if result is None:
		sys.exit(0)


def perform_installation(
	arch_config_handler: ArchConfigHandler,
	mirror_list_handler: MirrorListHandler,
	auth_handler: AuthenticationHandler,
	application_handler: ApplicationHandler,
	raw_config: dict,
) -> None:
	start_time = time.monotonic()
	info('Starting Kitest installation...')

	mountpoint = arch_config_handler.args.mountpoint
	config = arch_config_handler.config

	if not config.disk_config:
		error('No disk configuration provided')
		return

	disk_config = config.disk_config
	run_mkinitcpio = not config.bootloader_config or not config.bootloader_config.uki
	locale_config = config.locale_config
	optional_repositories = config.mirror_config.optional_repositories if config.mirror_config else []
	mountpoint = disk_config.mountpoint if disk_config.mountpoint else mountpoint

	with Installer(
		mountpoint,
		disk_config,
		kernels=config.kernels,
		silent=arch_config_handler.args.silent,
	) as installation:
		if disk_config.config_type != DiskLayoutType.Pre_mount:
			installation.mount_ordered_layout()

		installation.sanity_check(
			arch_config_handler.args.offline,
			arch_config_handler.args.skip_ntp,
			arch_config_handler.args.skip_wkd,
		)

		if disk_config.config_type != DiskLayoutType.Pre_mount:
			if disk_config.disk_encryption and disk_config.disk_encryption.encryption_type != EncryptionType.NoEncryption:
				installation.generate_key_files()

		if mirror_config := config.mirror_config:
			installation.set_mirrors(mirror_list_handler, mirror_config, on_target=False)

		installation.minimal_installation(
			optional_repositories=optional_repositories,
			mkinitcpio=run_mkinitcpio,
			hostname=config.hostname,
			locale_config=locale_config,
			pacman_config=config.pacman_config,
		)

		_enable_local_repo_if_available(installation, raw_config)

		if mirror_config := config.mirror_config:
			installation.set_mirrors(mirror_list_handler, mirror_config, on_target=True)

		if config.swap and config.swap.enabled:
			installation.setup_swap(algo=config.swap.algorithm)

		if config.bootloader_config and config.bootloader_config.bootloader != Bootloader.NO_BOOTLOADER:
			installation.add_bootloader(config.bootloader_config.bootloader, config.bootloader_config.uki, config.bootloader_config.removable)

		if config.network_config:
			install_network_config(config.network_config, installation, config.profile_config)

		users = None
		if config.auth_config and config.auth_config.users:
			users = config.auth_config.users
			installation.create_users(config.auth_config.users)
			auth_handler.setup_auth(installation, config.auth_config, config.hostname)

		if app_config := config.app_config:
			application_handler.install_applications(installation, app_config, users)

		if profile_config := config.profile_config:
			profile_handler.install_profile_config(installation, profile_config)

		if config.packages and config.packages[0] != '':
			installation.add_additional_packages(config.packages)

		if timezone := config.timezone:
			installation.set_timezone(timezone)

		if config.ntp:
			installation.activate_time_synchronization()

		if accessibility_tools_in_use():
			installation.enable_espeakup()

		if config.auth_config and config.auth_config.root_enc_password:
			root_user = User('root', config.auth_config.root_enc_password, False)
			installation.set_user_password(root_user)

		if (profile_config := config.profile_config) and profile_config.profile:
			profile_config.profile.post_install(installation)
			if users:
				profile_config.profile.provision(installation, users)

		if services := config.services:
			installation.enable_service(services)

		if disk_config.has_default_btrfs_vols():
			btrfs_options = disk_config.btrfs_options
			snapshot_config = btrfs_options.snapshot_config if btrfs_options else None
			snapshot_type = snapshot_config.snapshot_type if snapshot_config else None
			if snapshot_type:
				bootloader = config.bootloader_config.bootloader if config.bootloader_config else None
				installation.setup_btrfs_snapshot(snapshot_type, bootloader)

		if cc := config.custom_commands:
			run_custom_user_commands(cc, installation)

		_run_bootstrap_and_postinstall(installation, raw_config)

		debug(f'Disk states after installing:\n{disk_layouts()}')

		if not arch_config_handler.args.silent:
			elapsed_time = time.monotonic() - start_time
			action: PostInstallationAction = tui.run(lambda: select_post_installation(elapsed_time))
			match action:
				case PostInstallationAction.EXIT:
					pass
				case PostInstallationAction.REBOOT:
					_ = os.system('reboot')  # type: ignore[deprecated]
				case PostInstallationAction.CHROOT:
					try:
						installation.drop_to_shell()
					except Exception:
						pass


def main(arch_config_handler: ArchConfigHandler | None = None) -> None:
	if arch_config_handler is None:
		arch_config_handler = ArchConfigHandler()

	raw_config = apply_kitest_defaults(arch_config_handler)

	mirror_list_handler = MirrorListHandler(
		offline=arch_config_handler.args.offline,
		verbose=arch_config_handler.args.verbose,
	)

	if not arch_config_handler.args.silent:
		show_menu(arch_config_handler, mirror_list_handler)

	config = ConfigurationOutput(arch_config_handler.config)
	config.write_debug()
	config.save()

	if arch_config_handler.args.dry_run:
		return

	if not arch_config_handler.args.silent:
		aborted = False
		res: bool = tui.run(config.confirm_config)
		if not res:
			debug('Installation aborted')
			aborted = True
		if aborted:
			return main(arch_config_handler)

	if arch_config_handler.config.disk_config:
		fs_handler = FilesystemHandler(arch_config_handler.config.disk_config)
		if not delayed_warning(tr('Starting device modifications in ')):
			return main()
		fs_handler.perform_filesystem_operations()

	perform_installation(
		arch_config_handler,
		mirror_list_handler,
		AuthenticationHandler(),
		KitestApplicationHandler(),
		raw_config,
	)


if __name__ == '__main__':
	main()

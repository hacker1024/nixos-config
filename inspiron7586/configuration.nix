{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "22.05";

  nix.settings = {
    trusted-users = [ "@wheel" ];
    keep-derivations = true;
    keep-outputs = true;
    auto-optimise-store = true;
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = false;
    allowInsecurePredicate =
      (pkg: builtins.elem (lib.getName pkg) [ "qtwebkit" "electron" ]);
  };

  boot = {
    loader = {
      efi = {
        efiSysMountPoint = "/boot/efi";
        canTouchEfiVariables = true;
      };
      systemd-boot = {
        enable = true;
        consoleMode = toString 2;
        netbootxyz.enable = true;
        memtest86.enable = true;
      };
    };
    supportedFilesystems = [ "ext4" "vfat" "exfat" "ntfs" ];
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    kernelPatches = [{
      name = "Inspiron 7586 ELAN battery quirk";
      patch = ../common/hardware/inspiron7586/kernel/elan_battery.patch;
    }];
    kernelParams = [ "mitigations=off" ];
    kernelModules = [
      "apfs"
      #"ddcci" # Broken with Linux 6.1
    ];
    extraModulePackages = with config.boot.kernelPackages;
      [
        (stdenv.mkDerivation {
          pname = "apfs";
          version = "unstable-2022-10-20-${kernel.version}";

          src = pkgs.fetchFromGitHub {
            owner = "linux-apfs";
            repo = "linux-apfs-rw";
            rev = "e6eb67c92d425d395eac1c4403629391bdd5064d";
            sha256 = "sha256-6rv5qZCjOqt0FaNFhA3tYg6/SdssvoT8kPVhalajgOo=";
          };

          hardeningDisable = [ "pic" ];
          nativeBuildInputs = kernel.moduleBuildDependencies;

          makeFlags = kernel.makeFlags ++ [
            "KERNELRELEASE=${kernel.modDirVersion}"
            "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            "INSTALL_MOD_PATH=$(out)"
          ];

          meta = with lib; {
            description = "APFS module for linux";
            homepage = "https://github.com/linux-apfs/linux-apfs-rw";
            license = licenses.gpl2Only;
            platforms = platforms.linux;
            #broken = kernel.kernelOlder "4.9";
            maintainers = with maintainers; [ Luflosi ];
          };
        })
        #ddcci-driver # Broken with Linux 6.1
      ];
    tmpOnTmpfs = true;
    binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
    plymouth = {
      enable = true;
      theme = "spinner";
    };
  };

  hardware = {
    enableAllFirmware = true;
    opengl = {
      enable = true;
      extraPackages = with pkgs; [ intel-media-driver intel-compute-runtime ];
      driSupport = true;
      driSupport32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
        offload.enable = true;
      };
    };
    nvidiaOptimus.disable = true;
    bluetooth = {
      enable = true;
      settings.General.Experimental = true;
    };
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "modesetting" "nvidia" ];
    layout = "au";
    displayManager.sddm.enable = true;
    desktopManager.plasma5 = {
      enable = true;
      supportDDC = false;
    };
    displayManager.defaultSession = "plasmawayland";
  };

  virtualisation.virtualbox.host = {
    enable = true;
    enableExtensionPack = true;
  };
}

default:
    @just --list

fix:
    ./scripts/check-fix.sh

check:
    ./scripts/check-fix.sh --check

check-all:
    ./scripts/check-fix.sh --all-hosts

switch:
    sudo nixos-rebuild switch --flake .

update:
    nix flake update

clean:
	sudo nix-collect-garbage -d

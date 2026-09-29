{
  description = "Python Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          python3
          uv # fast venv + package management, drop-in for pip/virtualenv

          # Linting, formatting, type-checking
          ruff
          basedpyright
        ];

        shellHook = ''
          echo "🐍 Python environment loaded"
          echo "Python: $(python3 --version)"
          export PROJECT_ROOT=$PWD
          export UV_PROJECT_ENVIRONMENT=.venv

          # Create virtual environment if it doesn't exist
          if [ ! -d ".venv" ]; then
            echo "Creating virtual environment..."
            uv venv
          fi
          source .venv/bin/activate

          echo "💡 Add project dependencies with 'uv pip install <package>'"
        '';
      };
    });
}

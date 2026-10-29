"""Run actual Luau code outside Unicode-path limitations in Windows CLI 0.744."""
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--luau-dir', required=True, type=Path)
    args = parser.parse_args()
    suffix = '.exe' if os.name == 'nt' else ''

    def binary(name):
        return str((args.luau_dir / (name + suffix)).resolve())

    with tempfile.TemporaryDirectory(prefix='slime-validation-') as staging:
        stage = Path(staging)
        shutil.copytree(ROOT / 'src', stage / 'src')
        shutil.copytree(ROOT / 'tests', stage / 'tests')
        subprocess.run([binary('luau'), 'tests/beta.spec.luau'], cwd=stage, check=True)
        subprocess.run([binary('luau-analyze'), 'src/server/GameDomain.luau',
                        'src/server/ProfileSchema.luau', 'src/server/Lease.luau',
                        'src/server/ResourceService.luau',
                        'src/shared/Catalog.luau', 'src/shared/Protocol.luau',
                        'tests/beta.spec.luau'], cwd=stage, check=True)
        files = [p.relative_to(stage).as_posix() for p in (stage / 'src').rglob('*.luau')]
        subprocess.run([binary('luau-compile'), '--null', *files], cwd=stage, check=True)


if __name__ == '__main__':
    main()

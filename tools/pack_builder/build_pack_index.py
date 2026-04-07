import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def sha256_of_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def build_zip(pack_dir: Path, dist_dir: Path) -> Path:
    manifest = json.loads((pack_dir / 'manifest.json').read_text(encoding='utf-8'))
    pack_id = manifest['id']
    version = manifest['version']
    zip_name = f"{pack_id}-{version}.zip"
    zip_path = dist_dir / zip_name

    with zipfile.ZipFile(zip_path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(pack_dir / 'manifest.json', arcname='manifest.json')
        zf.write(pack_dir / 'puzzles.json', arcname='puzzles.json')

    return zip_path


def build_index(dist_dir: Path, base_url: str) -> Path:
    packs = []
    for zip_path in sorted(dist_dir.glob('*.zip')):
        with zipfile.ZipFile(zip_path, 'r') as zf:
            if 'manifest.json' not in zf.namelist():
                continue
            manifest = json.loads(zf.read('manifest.json').decode('utf-8'))

        pack_id = manifest['id']
        version = manifest['version']
        name = manifest.get('name', pack_id)
        puzzle_count = int(manifest.get('puzzleCount', 0))

        packs.append(
            {
                'id': pack_id,
                'name': name,
                'version': version,
                'puzzleCount': puzzle_count,
                'url': f"{base_url.rstrip('/')}/{zip_path.name}",
                'sha256': sha256_of_file(zip_path),
            }
        )

    index_path = dist_dir / 'index.json'
    index_path.write_text(json.dumps({'packs': packs}, indent=2), encoding='utf-8')
    return index_path


def main() -> None:
    parser = argparse.ArgumentParser(description='Build puzzle pack zip and index.json')
    parser.add_argument('--pack-dir', required=True, help='Directory containing manifest.json and puzzles.json')
    parser.add_argument('--dist-dir', default='sample_packs/dist', help='Output directory for zip and index')
    parser.add_argument('--base-url', default='http://localhost:8000', help='Base URL where files are hosted')
    args = parser.parse_args()

    pack_dir = Path(args.pack_dir)
    dist_dir = Path(args.dist_dir)
    dist_dir.mkdir(parents=True, exist_ok=True)

    zip_path = build_zip(pack_dir, dist_dir)
    index_path = build_index(dist_dir, args.base_url)

    print(f'Built: {zip_path}')
    print(f'Index: {index_path}')


if __name__ == '__main__':
    main()

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class ExpectedPath:
    path: Path
    kind: str


def expected_paths(root: Path) -> tuple[ExpectedPath, ...]:
    return (
        ExpectedPath(root / "ClimateCloset.xcodeproj", "dir"),
        ExpectedPath(root / "ClimateCloset", "dir"),
        ExpectedPath(root / "ClimateCloset" / "Assets.xcassets", "dir"),
        ExpectedPath(root / "ClimateCloset" / "LaunchScreen.storyboard", "file"),
        ExpectedPath(root / "ClimateClosetTests", "dir"),
        ExpectedPath(root / "ClimateClosetIntegrationTests", "dir"),
        ExpectedPath(root / "docs" / "USER_GUIDE.md", "file"),
        ExpectedPath(root / ".github" / "workflows" / "ci.yml", "file"),
    )


def validate_paths(paths: Iterable[ExpectedPath]) -> list[str]:
    errors: list[str] = []
    for entry in paths:
        if entry.kind == "dir" and not entry.path.is_dir():
            errors.append(f"Missing directory: {entry.path}")
        if entry.kind == "file" and not entry.path.is_file():
            errors.append(f"Missing file: {entry.path}")
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate_paths(expected_paths(root))
    if errors:
        for error in errors:
            print(error)
        return 1
    print("Climate Closet repository layout looks good.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

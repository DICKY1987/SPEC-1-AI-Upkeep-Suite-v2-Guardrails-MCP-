"""Command-line interface template aligned with AIUOKEEP guardrails."""
from __future__ import annotations

import argparse
import logging
import sys
from typing import Sequence


LOGGER = logging.getLogger("aiuokeep.template")


def configure_logging(verbosity: int) -> None:
    """Configure root logging according to verbosity level."""
    level = logging.WARNING
    if verbosity == 1:
        level = logging.INFO
    elif verbosity >= 2:
        level = logging.DEBUG

    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )


def build_parser() -> argparse.ArgumentParser:
    """Create an argument parser for the CLI."""
    parser = argparse.ArgumentParser(
        description="AIUOKEEP starter CLI. Replace commands with project-specific logic.",
    )
    parser.add_argument(
        "--verbosity",
        "-v",
        action="count",
        default=0,
        help="Increase logging verbosity (can be specified multiple times).",
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to the input resource.",
    )
    return parser


def execute(input_path: str) -> int:
    """Execute main business logic.

    Args:
        input_path: Path to the resource provided by the user.

    Returns:
        int: Exit status code. Return non-zero to signal failure.
    """
    LOGGER.info("Processing input: %s", input_path)
    # TODO: Implement business logic here. Avoid side effects without validation.
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    """Program entrypoint."""
    parser = build_parser()
    args = parser.parse_args(argv)

    configure_logging(args.verbosity)
    LOGGER.debug("CLI arguments: %s", args)

    try:
        return execute(args.input)
    except Exception as error:  # pylint: disable=broad-except
        LOGGER.exception("Unhandled exception")
        return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python
"""
Updates pins in this repo to their latest version.

This is a custom pinning tool, written because npins doesn't have narHash
compatible output for git inputs (it is not SRI), and also doesn't support the
Nix immutable tarball protocol which we would like to use when we become public.
"""
import subprocess
import tempfile
from pathlib import Path
import re
import dataclasses
from typing import Literal
import urllib.parse
import json


# https://stackoverflow.com/a/51286749
class DataclassJSONEncoder(json.JSONEncoder):

    def default(self, o):
        if dataclasses.is_dataclass(o):
            return dataclasses.asdict(o)
        return super().default(o)


@dataclasses.dataclass
class PinSerialized:
    kind: str
    rev: str | None
    nar_hash: str


@dataclasses.dataclass
class GitPinSerialized(PinSerialized):
    kind: Literal['git']
    url: str
    rev: str
    ref: str


@dataclasses.dataclass
class TarballPinSerialized(PinSerialized):
    kind: Literal['tarball']
    locked_url: str
    url: str


class PinSpec:

    def do_pin(self) -> dict[str, str]:
        raise ValueError('unimplemented')


@dataclasses.dataclass
class GitPinSpec(PinSpec):
    url: str
    branch: str

    def do_pin(self) -> GitPinSerialized:
        return lock_git(self.url, self.branch)


@dataclasses.dataclass
class TarballPinSpec(PinSpec):
    url: str

    def do_pin(self) -> TarballPinSerialized:
        return lock_tarball(self.url)


@dataclasses.dataclass
class LinkHeader:
    url: str
    rev: str | None


LINK_HEADER_RE = re.compile(r'<(?P<url>.*)>; rel="immutable"')


def parse_link_header(header) -> LinkHeader | None:
    matched = LINK_HEADER_RE.match(header)
    if not matched:
        return None

    url = matched.group('url')
    parsed_url = urllib.parse.urlparse(url)
    parsed_qs = urllib.parse.parse_qs(parsed_url.query)

    return LinkHeader(url=url, rev=next(iter(parsed_qs.get('rev', [])), None))


def lock_tarball(url) -> TarballPinSerialized:
    """
    Prefetches a tarball using the Nix immutable tarball protocol
    """
    import requests
    resp = requests.get(url)
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        proc = subprocess.Popen(["tar", "-C", td, "-xvzf", "-"],
                                stdin=subprocess.PIPE)
        assert proc.stdin
        for chunk in resp.iter_content(64 * 1024):
            proc.stdin.write(chunk)
        proc.stdin.close()
        if proc.wait() != 0:
            raise RuntimeError("untarring failed")

        children = list(td.iterdir())
        # FIXME: allow different tarball structures
        assert len(children) == 1

        child = children[0].rename(children[0].parent.joinpath('source'))
        sri_hash = subprocess.check_output(
            ["nix-hash", "--type", "sha256", "--sri", child]).decode().strip()
        path = subprocess.check_output(
            ["nix-store", "--add-fixed", "--recursive", "sha256",
             child]).decode().strip()

    link_info = parse_link_header(resp.headers['Link'])

    print(sri_hash, path)
    return TarballPinSerialized(kind='tarball',
                                nar_hash=sri_hash,
                                locked_url=link_info.url if link_info else url,
                                rev=link_info.rev if link_info else None,
                                url=url)


def lock_git(url, branch) -> GitPinSerialized:
    url_escaped = json.dumps(url)
    ref_escaped = json.dumps(branch)
    data = json.loads(
        subprocess.check_output([
            "nix", "eval", "--impure", "--json", "--expr",
            f"builtins.removeAttrs (builtins.fetchGit {{ url = {url_escaped}; ref = {ref_escaped}; }}) [ \"outPath\" ]"
        ]).strip())
    return GitPinSerialized(kind='git',
                            url=url,
                            rev=data['rev'],
                            ref=branch,
                            nar_hash=data['narHash'])


PINS = {
    'nix-eval-jobs':
    GitPinSpec('git@git.lix.systems:lix-project/nix-eval-jobs', 'main')
}


def main():
    output = {}
    for (name, pin) in PINS.items():
        output[name] = pin.do_pin()

    print(output)
    with open('pins.json', 'w') as fh:
        json.dump(output, fh, cls=DataclassJSONEncoder)


if __name__ == '__main__':
    main()

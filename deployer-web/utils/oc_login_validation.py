"""
Validation of user-supplied `oc login` commands.

Only an allowlist of flags is accepted. Flags such as --token-file, --kubeconfig, --config,
--client-key, --client-certificate or --certificate-authority are rejected so that callers
cannot make `oc` read or write arbitrary files on the deployer host (CWE-88).
"""

from typing import List

VALUE_FLAGS = {'--token', '--username', '-u', '--password', '-p', '--server', '-s'}
SERVER_FLAGS = {'--server', '-s'}
BOOL_FLAGS = {'--insecure-skip-tls-verify'}


def validate_oc_login_args(args: List[str]) -> List[str]:
    """
    Validate a parsed `oc login` argument list.

    Args:
        args: Argument list, e.g. ['oc', 'login', 'https://api:6443', '--token=xxx']

    Returns:
        The validated argument list.

    Raises:
        ValueError: If the command is not a plain `oc login` using only allowed flags.
    """
    if len(args) < 3 or args[0] != 'oc' or args[1] != 'login':
        raise ValueError('Not an oc login command')

    servers = []
    i = 2
    while i < len(args):
        arg = args[i]
        if arg.startswith('-'):
            name, has_value, value = arg.partition('=')
            if name in VALUE_FLAGS:
                if not has_value:
                    i += 1
                    if i >= len(args):
                        raise ValueError('Missing value for flag')
                    value = args[i]
                if name in SERVER_FLAGS:
                    servers.append(value)
            elif name in BOOL_FLAGS:
                if has_value and value.lower() not in ('true', 'false'):
                    raise ValueError('Invalid flag value')
            else:
                raise ValueError('Flag not allowed')
        else:
            servers.append(arg)
        i += 1

    if len(servers) != 1 or not servers[0].startswith(('https://', 'http://')):
        raise ValueError('Exactly one server URL is required')

    return args

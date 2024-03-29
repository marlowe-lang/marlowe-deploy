from argparse import ArgumentParser
from configparser import ConfigParser
from hetzner.robot import Robot
from hetzner import RobotError
import tomllib

parser = ArgumentParser(prog="prepare-rescue", description="Prepare the Hetzner machine in rescue mode")
parser.add_argument('-a', '--auth-config', help="The location of the authorization configuration", required=True)
parser.add_argument('-u', '--users', help="The location of the users.toml file", required=True)
parser.add_argument('-s', '--server-addr', help="The IP address of the server", required=True)

args = parser.parse_args()

auth_config = ConfigParser()
auth_config.read(args.auth_config)

with open(args.users, 'rb') as f:
    users = tomllib.load(f)

robot = Robot(auth_config['login']['username'], auth_config['login']['password'])
print("Fetching known SSH keys")
try:
    ssh_keys = { k['key']['data']: k['key']['fingerprint'] for k in robot.conn.get('/key') }
except RobotError as e:
    if e.status is not None and not e.status == 404:
        raise
    ssh_keys = {}

def gen_fingerprints():
  for user,settings in users.items():
      if settings['admin']:
          for key in settings['keys']:
              if key in ssh_keys:
                  yield ssh_keys[key]
              else:
                print(f"Uploading key {key}")
                res = robot.conn.post('/key', {'name': f"marlowe-deploy-{user}", 'data': key})
                yield res['key']['fingerprint']

fingerprints = list(gen_fingerprints())

server = robot.servers.get(args.server_addr)
print("Rebooting in rescue mode")
server.rescue.observed_activate(authorized_keys=fingerprints,tries=['hard'])
print("Disabling rescue mode for next reboot")
server.rescue.deactivate()

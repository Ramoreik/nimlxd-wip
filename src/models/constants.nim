import strformat

const SOCK* = "http+unix://%2fvar%2fsnap%2flxd%2fcommon%2flxd%2funix.socket"
const VERSION* = "1.0"

# Eventually import this ?
# https://github.com/lxc/lxd/blob/master/doc/rest-api.yaml

const INSTANCES_ENDPOINT* = fmt"/{VERSION}/instances"
const OPERATIONS_ENDPOINT* = fmt"/{VERSION}/operations"
const OPERATIONS_WAIT_ENDPOINT* = fmt"/{VERSION}/operations/$#/wait"
const INSTANCES_STATE_ENDPOINT* = fmt"/{VERSION}/instances/$#/state"
const INSTANCES_CONSOLE_ENDPOINT* = fmt"/{VERSION}/instances/$#/console"
const INSTANCES_BACKUPS_ENDPOINT* = fmt"/{VERSION}/instances/$#/backups"
const CERTIFICATES_ENDPOINT* = fmt"/{VERSION}/certificates"
const CLUSTER_ENDPOINT* = fmt"/{VERSION}/cluster"
const IMAGES_ENDPOINT* = fmt"/{VERSION}/images"
const NETWORK_ACL_ENDPOINT* = fmt"/{VERSION}/network-acls"
const NETWORK_ZONES_ENDPOINT* = fmt"/{VERSION}/network-zones"
const NETWORKS_ENDPOINT* = fmt"/{VERSION}/networks"
const PROFILES_ENDPOINT* = fmt"/{VERSION}/profiles"
const PROJECTS_ENDPOINT* = fmt"/{VERSION}/projects"
const STORAGE_POOLS_ENDPOINT* = fmt"/{VERSION}/storage-pools"
const WARNING_ENDPOINT* = fmt"/{VERSION}/warnings"

const DOWNLOAD_PROTOCOL* = "simplestreams"
const IMAGES_REMOTE_SERVER* = "https://images.linuxcontainers.org"
const IMAGES_REMOTE_URL* = "https://us.lxd.images.canonical.com/streams/v1/images.json"

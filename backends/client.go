package backends

import (
	"errors"
	"strings"

	"github.com/kelseyhightower/confd/backends/consul"
	"github.com/kelseyhightower/confd/backends/dynamodb"
	"github.com/kelseyhightower/confd/backends/env"
	"github.com/kelseyhightower/confd/backends/etcd"
	"github.com/kelseyhightower/confd/backends/rancher"
	"github.com/kelseyhightower/confd/backends/redis"
	"github.com/kelseyhightower/confd/backends/stackengine"
	"github.com/kelseyhightower/confd/backends/vault"
	"github.com/kelseyhightower/confd/backends/zookeeper"
	"github.com/kelseyhightower/confd/log"
)

// The StoreClient interface is implemented by objects that can retrieve
// key/value pairs from a backend store.
type StoreClient interface {
	GetValues(keys []string) (map[string]string, error)
	Set(key string, value string) error
	Remove(key string) error
	WatchPrefix(prefix string, keys []string, waitIndex uint64, stopChan chan bool) (uint64, error)
}

// New is used to create a storage client based on our configuration.
func New(config Config) (StoreClient, error) {
	if config.Backend == "" {
		config.Backend = "etcd"
	}
	backendNodes := config.BackendNodes
	log.Info("Backend nodes set to " + strings.Join(backendNodes, ", "))
	switch config.Backend {
	case "consul":
		return consul.New(config.BackendNodes, config.Scheme,
			config.ClientCert, config.ClientKey,
			config.ClientCaKeys)
	case "etcd":
		// Create the etcd client upfront and use it for the life of the process.
		// The etcdClient is an http.Client and designed to be reused.
		return etcd.NewEtcdClient(backendNodes, config.ClientCert, config.ClientKey, config.ClientCaKeys, config.BasicAuth, config.Username, config.Password)
	case "zookeeper":
		return zookeeper.NewZookeeperClient(backendNodes)
	case "rancher":
		return rancher.NewRancherClient(backendNodes)
	case "redis":
		return redis.NewRedisClient(backendNodes, config.ClientKey)
	case "env":
		return env.NewEnvClient()
	case "vault":
		vaultConfig := map[string]string{
			"app-id":   config.AppID,
			"user-id":  config.UserID,
			"username": config.Username,
			"password": config.Password,
			"token":    config.AuthToken,
			"cert":     config.ClientCert,
			"key":      config.ClientKey,
			"caCert":   config.ClientCaKeys,
		}
		return vault.New(backendNodes[0], config.AuthType, vaultConfig)
	case "dynamodb":
		table := config.Table
		log.Info("DynamoDB table set to " + table)
		return dynamodb.NewDynamoDBClient(table)
	case "stackengine":
		return stackengine.NewStackEngineClient(backendNodes, config.Scheme, config.ClientCert, config.ClientKey, config.ClientCaKeys, config.AuthToken)
	}
	return nil, errors.New("Invalid backend")
}

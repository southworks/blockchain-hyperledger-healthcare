# Environment Setup
To use Hyperledger fabric as a solution to the business logic proposed in our scenario, we need to configure the necessary components and entities as shown in the following step-by-step:
1)	Download the Hyperledger fabric prerequisite files.
2)	Create a blockchain network.
3)	Create a network channel.
4)	Create organization’s users.
5)	Deploy a chaincode to be used by the organization’s users.

We implemented a console application that allow us to setup all the necessary steps to create the Healthcare network. The following sub sections are a conceptual summary of each step.

## Prerequisites
Before starting the setup, it is necessary to download the Hyperledger fabric binaries files and Hyperledger fabric docker images to the local machine where we are going to create the network.

## Binaries
The binary files allow us to use the entire Hyperledger platform on a local machine. The following files are required to run the Healthcare network:
* Configtxgen: network configuration utilities.
* Configtxlator: network configuration utilities.
* Cryptogen: certificate generation utilities.
* Orderer: orderer utilities.
* Peer: peers’ utilities.
* Fabric-ca-client: certificate authorities’ utilities.
* Fabric-ca-server: server certificate authorities’ utilities.

## Docker Images
The docker images are used to create the necessary containers for some of our network’s components. The following images are required to run the network:
* Hyperledger/fabric-nodeenv
* Hyperledger/fabric-ca
* Hyperledger/fabric-baseos
* Hyperledger/fabric-ccenv
* Hyperledger/fabric-peer
* Hyperledger/fabric-orderer
* Hyperledger/fabric-tools
* Couchdb
<br/>
<br/>

# Network Setup
The first step to setup a network is to create the two basic components that a blockchain network needs, an Orderer node and a Peer Organization node.

## Orderer
As we said in the subsection "Orderer service", the Orderer node serves to oversee the transaction ordering and building the final block of transactions. Therefore, it is essential to create an Orderer node before any other component within our network. 

To setup a new Orderer the following processes must be done:
1)	**Certificate Creation:** A Certificate Authority is created using fabric-ca client on a fabric-ca-server running in a docker container.
2)	**Register and Enroll users:** Users are registered and enrolled using the previously issued Certificate Authority. As output we have an admin user and an orderer user created.
3)	**Docker container creation:** A yaml file is used to create and run a container configured as an Orderer node. 
4)	**Create system-channel:** A system channel is created; this channel contains a configuration block defining the network at a system level. It lives within the ordering service, and similar to a channel, has an initial configuration containing information such as: MSP information, policies, and configuration details.

## Organizations
On the other hand, the Peer Organizations are the nodes in charge of hosting the ledgers and smart contracts. It is indispensable to have at least one peer organization per blockchain network.

To setup a new peer organization the following processes must be done:
1)	**Certificate Creation:** A Certificate Authority is created using fabric-ca client on a fabric-ca-server running in a docker container.
2)	**Register and Enroll users:** Users are registered and enrolled using the previously issued Certificate Authority. As output have an admin user and a peer user created.
3)	**Peer docker container creation:** A yaml file is used to create and run a container configured as a Peer organization node.
4)	**Client docker container creation:** A yaml file is used to create and run a container configured as a client depending on a peer organization.
5)	**Create CouchDB:** A database that holds a cache of the current values of a set of ledger states is created. A yaml file is used to create and run a container configured as a CouchDB database depending on a peer organization.

## Channel
Once the network is created, we need a virtual space where we can execute operations between organizations. These virtual spaces are called channels and any organization can propose the creation of one. Within them, each party must authenticate and authorize transactions.

To setup a new channel the following processes must be done:
1)	**Create a channel config:** A channel config is created using a channel profile from the config.yaml file. 
2)	**Use configs to create the channel:** The channel is started with the previous configs.
3)	**Join the organizations to the channel:** This process consists of two parts. on the first part, the channel settings are updated to be able to receive a new member, and on the second part, an anchor peer per member is created to be used as a communication node between organizations within a channel.

## Organization's Users
As explained in the taxonomy diagram, each organization has a hierarchy of users. Just as creating a channel or joining an organization to a channel requires an admin user, a client user is required to use the chaincode methods.

## User's Data
Each client user has three important values for registration and enrollment.
1)	Identity within the organization (Username).
2)	Passwords to validate identity within the organization (User password).
3)	Permission role to operate the chaincode methods (User role).

## Chaincode Management
As a last step, peers need a chaincode to be able to operate with the blockchain. The chaincode will contain the methods that will be executed depending on the method that is invoked. Through these methods we will be able to record information in our blockchain.

To deploy a chaincode on an organization the following processes must be done:
1)	**Installation:** the chaincode must be packaged and then installed on the organization and a specific channel.
2)	**Approval:** each organization must approve the chaincode to deploy it according to the installation policies. This step also configures the chaincode endorsement policy, which defines which network actors need to endorse a transaction for it to be valid.
3)	**Init:** Finally, an initial method called “initLedger” is invoked to start the ledger.

After all these steps, the network is set and ready to be utilized by the organizations and organization’s users.
<br/>
<br/>

# Network Scripts

The scripts folder contains bash scripts to automate the network setup.
The scripts are the following.

- [install](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/install.sh)
- [createNetwork](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/createNetwork.sh)
- [createChannel](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/createChannel.sh)
- [joinOrganizations](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/joinOrganizations.sh)
- [deploycc](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/deploycc.sh)
- [createUser](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/createUser.sh)
- [addOrganization](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/addOrganization.sh)
- [addPeer](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/addPeer.sh)
- [joinPeerToChannel](https://github.com/southworks/skadar/blob/main/dev/fabric-network/scripts/joinPeerToChannel.sh)

All these scripts can be managed by using a main script called **bc-network.sh**

```bash
./bc-networks.sh [COMMANDS]
```

## Blockchain network setup

### Prerequisites

- On windows, have **[chocolatey](https://chocolatey.org/)** installed.

### Required applications

To setup a blockchain network, you need to have the following applications installed on your local machine:

- Git
- cURL
- Docker
- Docker Compose

To install the required applications execute the following commands:

```bash
 install prereqs
```

Then, you need to download the latest versions of the hyperledger images and the hyperledger binary files to be able to run the console commands correctly. For that, execute the following commands:

```bash
 install bootstrap
```

### Create a Network

To create a blockchain network execute the following commands:

```bash
 network create --org ORG1 --admin-user ADMIN_USERNAME --admin-pwd ADMIN_PASSWORD
```

When the script finishes, the output will have all the necessary containers running and an operative Blockchain Network with a main organization.

### Create a Channel

To create a channel execute the following commands:

```bash
 channel create --channel-name CHANNEL_NAME --org-creator CREATOR_ORG1
```

### Join the organizations to the channel

To join an organization to a channel, execute the following commands:

```bash
 channel join --channel-name CHANNEL_NAME --org ORG1
```

### Deploy chaincode on the organizations

To deploy a chaincode on an organization that belongs to a channel, execute the following commands:

```bash
 chaincode deploy org --cc-name CC_NAME --cc-path CC_PATH --cc-version CC_VERSION --cc-sequence CC_SEQUENCE --channel-name CHANNEL_NAME --org ORG1
```

### Invoke chaincode

To invoke a chaincode, execute the following commands:

```bash
 chaincode invoke --cc-name CC_NAME --cc-args CC_FUNCTION --user-name USER_NAME --channel-name CHANNEL_NAME --org ORG 
```

CC_FUNCTION example:

```bash
'{"Args":["HealthCenter:CreateEmr","{\"patientId\":\"1010\",\"patientName\":\"patient1\",\"patientBirthdate\":\"10-03\"}"]}'
```

### Create a Blockchain User

To create a blockchain user, execute the following commands:

```bash
 user create --user-name USER_NAME --user-pwd USER_PASSWORD --user-role USER_ROLE --channel-name CHANNEL_NAME --org ORG
```

### List Blockchain Users

To list the blockchain users, execute the following commands:

```bash
 user list --org ORG1
```

### Add a new Organization

To add a new organization to the blockchain network execute the following commands:

```bash
 network add-org --org ORG2 --admin-user ADMIN_USERNAME --admin-pwd ADMIN_PASSWORD
```

### Add a new Peer to an Organization

To add a new Peer to an organization execute the following commands:

```bash
 peer create --org ORG2 --admin-user ADMIN_USERNAME --admin-pwd ADMIN_PASSWORD
```

### Deploy chaincode on a peer

To deploy a chaincode on a peer that belongs to an organization, execute the following commands:

```bash
 chaincode deploy peer --cc-name CC_NAME --channel-name CHANNEL_NAME --org ORG1 --peer PEER_ID
```

### Join the organizations to the channel

To join a new peer to a channel, execute the following commands:

```bash
 peer join --channel-name CHANNEL_NAME --org ORG1 --peer PEER_ID

```
### Invoke chaincode with another peer

To invoke a chaincode with another peer, execute the following commands:

```bash
 chaincode invoke --cc-name CC_NAME --cc-args CC_FUNCTION --user-name USER_NAME --channel-name CHANNEL_NAME --org ORG --peer PEER_ID
```

### Delete a Network

To delete a blockchain network and its dependencies, execute the following commands:

```bash
./bc-blockchain.sh network delete
```

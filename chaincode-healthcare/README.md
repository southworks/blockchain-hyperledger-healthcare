# Solution Chaincode
The chaincode created for the Healthcare solution consists of a set of smart contracts that execute the business logic and allow users to manage the EMRs in the blockchain.

For this chaincode we decided to define an endorsement policy that requires every organization to endorse transactions. This prevents any one Medical Provider to perform an invalid transaction and corrupt the distributed ledger.

## Chaincode Design
In the Hyperledger Fabric framework, chaincodes act as namespaces that group together smart contracts that manipulate the same data. This means smart contracts in different chaincodes cannot directly access each other’s data. Because of this, we decided to group all available operations in one chaincode which is installed on every Medical Provider peer node. 

However, since we wanted to restrict certain users from performing certain operations, we decided to implement an Attribute Based Access Control (ABAC). This control consists of restricting access based upon a user’s identity attribute found on their certificate.

## ABAC Role Middleware
Our solution uses an attribute called userRole that is added to the user’s certificates when they are registered. This attribute specifies the user role in the network, which can either be healthcenter, physician, or patient. Additionally, a permission list is stored in the peers’ ledgers by the initLedger function. The list specifies which operations can be performed by each user role. 

When a user wants to interact with the network (using his/her certificate), the chaincode will check the userRole value and compare it to the permission list to decide whether he/she has permission to perform the operation. 

## EMR Access Restriction
As we have shown throughout this article, any data stored in the ledger by a Health Provider is replicated in all other organization’s ledgers to prevent any tampering. Unfortunately, this means that any Health Provider could in theory access sensitive data from a patient that belongs to a different organization in the network.

The mechanism that prevents this from happening in our solution is implemented in the Chaincode itself. When a user from a Health Provider invokes a chaincode operation, the chaincode can access the user’s certificate data, among which is the user’s organization id.

The chaincode uses the caller’s organization id to form the EMR id, both when an EMR is created and when it is retrieved. In practice this means a user from one Health Provider will never be able to see or retrieve an EMR from a patient belonging to another Health Provider. Even if the user knows the other organization’s id, he could not access the data since the chaincode gets the id directly from the user’s certificate at runtime.

Since sometimes a patient’s EMR wants to be shared between organizations. We added a chaincode operation to retrieve a shared EMR which verifies that both the EMR owner organization and the patient have agreed to share it with this organization.

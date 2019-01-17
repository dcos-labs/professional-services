 

<table>
  <tr>
    <td> 
   
DC/OS Security Considerations
Certificates
 </td>
  </tr>
  <tr>
    <td></td>
  </tr>
</table>


# Overview - Summary of Requirements

As new customers or existing customers implement later versions of DC/OS (1.11), they may decide to change security mode on their cluster and use certificates in a more specific manner. The concerns include the following (known at this time):

* What do other DC/OS customers implement for certificates in their clusters

* What do we see as an industry standard for implementing certs in support of DC/OS 

* Which cert would best suit a customer and their needs: Wildcard, DC/OS generated CA bundle, existing implemented CA-intermediate/root  

* Deploying a large number of services with different APIs thusly requiring a lot of different certificates

* Methodology of deploying a lot of services with unique certificates and how best to integrate with Marathon

    * Cert per service 

* Permissive vs strict mode for operating the cluster 

* It should be noted, that configuration option, "security: disabled" will be decommissioned with DC/OS 1.12, due for GA release at the end of FY2018 

Considerations

Assigning a certificate for each deployed service does present a lot of management/care overhead. In light of this, wildcard certs do seem attractive from an ease-of-use perspective. However, the team deploying/managing DC/OS is not (necessarily) the same team which manages security within the environment and the existing CA environment; thus there would be redundancy in effort and there maybe drift in common security practices. 

Recommendation(s) 

Mesosphere supports (and encounters) customers that do wildcard, DC/OS CA bundle, and existing implemented CA certs. While assigning a cert may be more difficult from a management perspective, a general recommendation is to use what the customer already has implemented, and, is comfortable with: the existing Root CA with intermediate certificates assigned to be used within DC/OS.  Additionally, more specifically, if the customer wants to implement certificates per container, wildcard certificates is not ideal for this implementation. 

In this implementation, certificates per application, would be inserted directly into services (containers) upon start, using DC/OS secrets. Supporting this implementation, the ingress load balancer (MLB), will have to be configured to forward TLS packets directly to containers and terminated directly at that container. This can be implemented with known configurations for MLB utilizing the SNI protocol (https://en.wikipedia.org/wiki/Server_Name_Indication). 

Regarding cluster security definition, it is recommended that all testing and integration be done with security set to: security: strict in config.yaml. Changing the security level post deployment (production) of the cluster will be tantamount to performing a cluster-wide configuration change and will change the behavior of the cluster. 

Implementation References

 Prior to further planning and design work, the following references should provide detail on how to implement DC/OS to achieve the production working environment for customer environments. 

<table>
  <tr>
    <td>Using Custom CA Certificate(s) with DC/OS </td>
  </tr>
  <tr>
    <td>https://docs.mesosphere.com/1.11/security/ent/tls-ssl/ca-custom/#installing-dcos-enterprise-with-a-custom-ca-certificate </td>
  </tr>
  <tr>
    <td>Installing DC/OS with a Custom CA Certificate</td>
  </tr>
  <tr>
    <td>https://docs.mesosphere.com/1.11/security/ent/tls-ssl/ca-custom/#installing-dcos-enterprise-with-a-custom-ca-certificate</td>
  </tr>
  <tr>
    <td>Using Secrets with DC/OS 1.11 </td>
  </tr>
  <tr>
    <td>https://docs.mesosphere.com/1.11/security/ent/secrets/</td>
  </tr>
  <tr>
    <td>Configuring Services and Pods to use Secrets </td>
  </tr>
  <tr>
    <td>https://docs.mesosphere.com/1.11/security/ent/secrets/use-secrets/</td>
  </tr>
  <tr>
    <td>Secrets API </td>
  </tr>
  <tr>
    <td>https://docs.mesosphere.com/1.11/security/ent/secrets/secrets-api/</td>
  </tr>
  <tr>
    <td>Deploying Pods and Services </td>
  </tr>
  <tr>
    <td>https://docs.mesosphere.com/1.11/deploying-services/</td>
  </tr>
  <tr>
    <td></td>
  </tr>
</table>



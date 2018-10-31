package cmd

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
)

type User struct {
	Username string `json:"uid"`
	Password string `json:"password"`
	Token    string `json:"token,omitempty"`
}

type Cluster struct {
	cluster_url string
	client      *http.Client
	user        User
}

// Consists of the path to the secret ("ID") and the AES-encrypted JSON definition.
// JSON format is dependent on DC/OS version, but generally will have a 'value' field.
type Secret struct {
	ID               string
	EncryptedContent []byte
	// binary bool
}

func createClient() *http.Client {
	// // Create transport to skip verify TODO: add certificate verification
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}

	client := &http.Client{
		Transport: tr,
	} // TODO: add timeouts here

	return client
}

func NewCluster(hostname string, username string, password string) (cluster *Cluster, err error) {
	if hostname == "" || username == "" || password == "" {
		fmt.Println("Please provide hostname, username, and password")
		return nil, errors.New("")
	}
	var c Cluster
	c.cluster_url = "https://" + hostname
	c.user = User{Username: username, Password: password}

	// Create JSON to login
	j, err := json.Marshal(c.user)
	if err != nil {
		fmt.Println("TODO: error handling here utility-cluster NewCluster")
		return nil, err
	}

	// Create client
	c.client = createClient()

	// Login and get token
	err = c.Login("/acs/api/v1/auth/login", j)

	return &c, err

}

func (c *Cluster) Login(path string, buf []byte) (err error) {
	fmt.Printf("Logging into cluster [%s]\n", c.cluster_url)
	url := c.cluster_url + path
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(buf))
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)

	if err != nil {
		fmt.Println("TODO: error handling here utility-cluster Login1")
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Println("Unable to login (Invalid credentials?)")
		return errors.New("Unable to login (Invalid credentials?)")
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("TODO: error handling here utility-cluster Login3")
		return err
	}

	// Will add token to user
	err = json.Unmarshal(body, &c.user)

	return err
}

// Basic wrapper that includes specifying the auth token
func (c *Cluster) Call(verb string, path string, headers map[string]string, buf []byte) (body []byte, returnCode int, header http.Header, err error) {
	url := c.cluster_url + path
	req, err := http.NewRequest(verb, url, bytes.NewBuffer(buf))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "token="+string(c.user.Token))

	// Add all headers
	for h, v := range headers {
		req.Header.Set(h, v)
	}

	resp, err := c.client.Do(req)

	if err != nil {
		fmt.Println("TODO: error handling here: request failed")
		return nil, 0, nil, err
	}
	defer resp.Body.Close()

	body, err = ioutil.ReadAll(resp.Body)

	return body, resp.StatusCode, resp.Header, err
}

// Get secret
func (c *Cluster) GetSecret(secretID string, cipherKey string, pool chan int, secretChan chan<- Secret) {
	<-pool // Wait for there to be an open spot in the pool
	defer func() {
		pool <- 0
	}()

	fmt.Printf("Getting secret '%s'\n", secretID)
	secretBody, returnCode, headers, err := c.Call("GET", "/secrets/v1/secret/default/"+secretID, nil, nil)
	if err != nil || returnCode != http.StatusOK {
		fmt.Printf("Unable to retrieve secret '%s'\n. [%d]: %s", secretID, returnCode, err.Error)
		secretChan <- Secret{ID: ""}
	} else {
		if headers.Get("content-type") == "application/octet-stream" {
			secretID = secretID + ".binary"
		}
		var econtent []byte
		econtent = encrypt(secretBody, cipherKey)
		secretChan <- Secret{ID: secretID, EncryptedContent: econtent}
	}
}

func (c *Cluster) GetSecrets(secrets []string, cipherKey string, secretChan chan Secret, psize int) {
	pool := make(chan int, psize)
	for i := 0; i < psize; i++ {
		pool <- 0
	}
	// Spins off a bunch of goroutines to get secrets and add them to secretChan.  Should be rate limited by psize
	for _, secretID := range secrets {
		go c.GetSecret(secretID, cipherKey, pool, secretChan)
	}
}

// Will attempt to PUT; if it gets a 409 back (i.e., a 'conflict'), will then attempt a PATCH
func (c *Cluster) PushSecret(secret Secret, cipherKey string, pool chan int, rchan chan<- int) {
	// We don't really need to throttle decryption / unmarshalling
	var content []byte
	content = decrypt(secret.EncryptedContent, cipherkey)

	binary := strings.HasSuffix(secret.ID, ".binary")
	headers := make(map[string]string)

	if binary {
		headers["content-type"] = "application/octet-stream"
	} else {
		// Can probably remove this - this has been superceded by the cipherkey validation
		var t struct {
			Value string `json:"value"`
		}
		err := json.Unmarshal(content, &t)
		if err != nil || t.Value == "" {
			fmt.Printf("Unable to decrypt [%s].  You likely have an invalid cipherkey.\n", secret.ID)
			os.Exit(1)
		}
	}

	secretID := strings.TrimSuffix(secret.ID, ".binary")
	fmt.Printf("Queueing secret [%s] ...\n", secretID)
	secretPath := "/secrets/v1/secret/default/" + secretID

	<-pool // throttle
	defer func() {
		pool <- 0
		rchan <- 0
	}()

	resp, code, _, err := c.Call("PUT", secretPath, headers, content)
	if code == 201 {
		fmt.Println("Secret [" + secretID + "] successfully created.")
	} else if code == 409 {
		// fmt.Printf("[%s] already exists, updating ...\n", secret.ID)
		presp, pcode, _, perr := c.Call("PATCH", secretPath, headers, content)
		if pcode == 204 {
			fmt.Println("Secret [" + secretID + "] successfully updated.")
		} else if perr != nil {
			fmt.Printf("Error when attempting to update [%s]: %s\n", secretID, perr.Error())
		} else {
			fmt.Printf("Error when attempting to update [%s]. [%s]: %s\n", secretID, pcode, string(presp))
		}
	} else if err != nil {
		fmt.Printf("Error when attempting to create [%s]: %s\n", secretID, err.Error())
	} else {
		fmt.Printf("Error when attempting to create [%s]. [%s]: %s\n", secretID, code, string(resp))
	}
}

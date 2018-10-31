// stolen from https://gist.github.com/josephspurrier/12cc5ed76d2228a41ceb

package cmd

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"

	"fmt"
	"io"
	"os"
	// "path/filepath"

	"archive/tar"
	"bytes"
)

// TODO: Support variable length keystring
func decrypt(data []byte, keystring string) []byte {
	// Key
	key := []byte(keystring)

	// Create the AES cipher
	block, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}

	// Before even testing the decryption,
	// if the text is too small, then it is incorrect
	if len(data) < aes.BlockSize {
		panic("Text is too short")
	}

	// Get the 16 byte IV
	iv := data[:aes.BlockSize]

	// Remove the IV from the data
	data = data[aes.BlockSize:]

	// Return a decrypted stream
	stream := cipher.NewCFBDecrypter(block, iv)

	// Decrypt bytes from data
	stream.XORKeyStream(data, data)

	return data
}

// TODO: Support variable length keystring
func encrypt(data []byte, keystring string) []byte {
	// Key
	key := []byte(keystring)

	// Create the AES cipher
	block, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}

	// Empty array of 16 + data length
	// Include the IV at the beginning
	ciphertext := make([]byte, aes.BlockSize+len(data))

	// Slice of first 16 bytes
	iv := ciphertext[:aes.BlockSize]

	// Write 16 rand bytes to fill iv
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		panic(err)
	}

	// Return an encrypted stream
	stream := cipher.NewCFBEncrypter(block, iv)

	// Encrypt bytes from data to ciphertext
	stream.XORKeyStream(ciphertext[aes.BlockSize:], data)

	return ciphertext
}

func writeTar(secrets []Secret, filename string) {
	f, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer f.Close()

	// Create a new tar archive.
	tw := tar.NewWriter(f)

	for _, secret := range secrets {
		hdr := &tar.Header{
			Name: secret.ID,
			Mode: 0600,
			Size: int64(len(secret.EncryptedContent)),
		}
		if err := tw.WriteHeader(hdr); err != nil {
			fmt.Println("Error writing header")
			// log.Fatalln(err)
		}
		if _, err := tw.Write((secret.EncryptedContent)); err != nil {
			fmt.Println("Error writing content")
			// log.Fatalln(err)
		}
	}
	// Make sure to check the error on Close.
	if err := tw.Close(); err != nil {
		fmt.Println("Error closing")
		// log.Fatalln(err)
	}
}

func readTar(filename string) (secrets []Secret) {
	secrets = []Secret{}
	f, err := os.Open(filename)
	if err != nil {
		panic(err)
	}
	defer f.Close()

	tr := tar.NewReader(f)

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			// end of tar archive
			break
		}
		if err != nil {
			fmt.Println("Error advancing")
			// log.Fatalln(err)
		}
		buf := new(bytes.Buffer)
		buf.ReadFrom(tr)
		s := buf.Bytes()
		secrets = append(secrets, Secret{ID: hdr.Name, EncryptedContent: s})
	}
	return secrets
}

// func createDirFor(path string) {
// 	dir := filepath.Dir(path)
// 	// fmt.Println(dir)
// 	os.MkdirAll(dir, os.ModePerm)
// }

func validateCipher() {
	if cipherkey == "" {
		cipherkey = "ThisIsAMagicKeyString12345667890"
	} else if len(cipherkey)%32 != 0 {
		fmt.Printf("'cipherkey' has a length of %d characters\n", len(cipherkey))
		fmt.Println("It must be a multiple of 32 characters long")
		os.Exit(1)
	}
}

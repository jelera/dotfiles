# Creates a directory and sets the PWD to it
take() {
	mkdir -p $1
	cd $1
}

# Generate a secure password
genpass() {
  openssl rand -base64 ${1:-16}
}

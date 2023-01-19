SCALE ?= 3

all: build

keyfile:
	openssl rand -base64 768 > keyfile

build: keyfile
	ansible-playbook -e scale=$(SCALE) -e pwd=$(shell pwd) execute.yml 

clean:
	- ansible-playbook destroy.yml
	- rm -rf inventory keyfile roles/mongodb/filter_plugins/__pycache__

dist-clean: clean
	- cd terraform && make dist-clean && cd ..

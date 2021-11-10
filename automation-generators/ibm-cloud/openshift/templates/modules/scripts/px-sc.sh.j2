#!/bin/sh

echo "creating storage classes"

# CouchDB (Implemented application-level redundancy)
cat <<EOF | kubectl create -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-couchdb-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# ElasticSearch (Implemented application-level redundancy)
cat <<EOF | kubectl create -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-elastic-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "2"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Solr
cat <<EOF | kubectl create -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-solr-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Cassandra
cat <<EOF | kubectl create -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-cassandra-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Kafka
cat <<EOF | kubectl create -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-kafka-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "3"
 priority_io: "high"
 io_profile: "db_remote"
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# metastoredb:
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-metastoredb-sc
parameters:
  priority_io: high
  io_profile: db_remote
  repl: "3"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# General Purpose, 3 Replicas - Default SC for other applications
# without specific SC defined and with RWX volume access mode - New Install
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-rwx-gp3-sc
parameters:
  priority_io: high
  repl: "3"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# General Purpose, 3 Replicas [Default for other applications without
# specific SC defined and with RWX volume access mode] - SC portworx-shared-gp3 for upgrade purposes
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp3
parameters:
  priority_io: high
  repl: "3"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# General Purpose, 2 Replicas RWX volumes
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-rwx-gp2-sc
parameters:
  priority_io: high
  repl: "2"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# DV - Single replica
cat <<EOF | kubectl create -f -
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp
parameters:
  block_size: 4096b
  priority_io: high
  repl: "1"
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# DV - three replicas
cat <<EOF | kubectl create -f -
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-dv-shared-gp3
parameters:
  block_size: 4096b
  priority_io: high
  repl: "3"
  shared: "true"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Streams
cat <<EOF | kubectl create -f -
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: portworx-shared-gp-allow
parameters:
 priority_io: high
 repl: "3"
 io_profile: "cms"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

#  General Purpose, 1 Replica - RWX volumes for TESTING ONLY.
cat <<EOF | kubectl create -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
 name: portworx-rwx-gp-sc
provisioner: kubernetes.io/portworx-volume
parameters:
 repl: "1"
 priority_io: "high"
 sharedv4: "true"
 io_profile: db_remote
 disable_io_profile_protection: "1"
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Delete
EOF

# General Purpose, 3 Replicas - RWX volumes - placeholder SC portworx-shared-gp for upgrade purposes
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp
parameters:
  priority_io: high
  repl: "3"
  sharedv4: "true"
  io_profile: db_remote
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF


# General Purpose, 3 Replicas RWO volumes rabbitmq and redis-ha - New Install
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-gp3-sc
parameters:
  priority_io: high
  repl: "3"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF


# General Purpose, 3 Replicas RWO volumes rabbitmq and redis-ha - placeholder SC portworx-nonshared-gp2 for upgrade purposes
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-nonshared-gp2
parameters:
  priority_io: high
  repl: "3"
  io_profile: "db_remote"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

#Shared gp high iops:
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-shared-gp1
parameters:
  priority_io: high
  repl: "1"
  sharedv4: "true"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# gp db
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp
parameters:
  io_profile: "db_remote"
  repl: "1"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# General Purpose for Databases, 2 Replicas - MongoDB - (Implemented application-level redundancy)
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp2-sc
parameters:
  priority_io: "high"
  io_profile: "db_remote"
  repl: "2"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# General Purpose for Databases, 3 Replicas
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db-gp3-sc
parameters:
  io_profile: "db_remote"
  repl: "3"
  priority_io: "high"
  disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF


# DB2 RWX shared volumes for System Storage, backup storage, future load storage, and future diagnostic logs storage
cat <<EOF | kubectl create -f -
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwx-sc
parameters:
  io_profile: cms
  block_size: 4096b
  nfs_v4: "true"
  repl: "3"
  sharedv4: "true"
  priority_io: high
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Db2 RWO volumes SC for user storage, future transaction logs storage, future archive/mirrors logs storage. This is also used for WKC DB2 Metastore
cat <<EOF | kubectl create -f -
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-rwo-sc
parameters:
  block_size: 4096b
  io_profile: db_remote
  priority_io: high
  repl: "3"
  sharedv4: "false"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# WKC DB2 Metastore - SC portworx-db2-sc for upgrade purposes
cat <<EOF | kubectl create -f -
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-sc
parameters:
  io_profile: "db_remote"
  priority_io: high
  repl: "3"
  disable_io_profile_protection: "1"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF



# Watson Assistant - This was previously named portworx-assistant
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-watson-assistant-sc
parameters:
   repl: "3"
   priority_io: "high"
   io_profile: "db_remote"
   block_size: "64k"
   disable_io_profile_protection: "1"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF


# FCI DB2 Metastore
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-db2-fci-sc
provisioner: kubernetes.io/portworx-volume
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
  block_size: 512b
  io_profile: db_remote
  priority_io: high
  repl: "3"
  disable_io_profile_protection: "1"
EOF

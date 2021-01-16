


NFS server:

```bash
yum -y install nfs-utils

mkdir /var/nfsshare
```

```bash
chmod -R 755 /var/nfsshare
chown nfsnobody:nfsnobody /var/nfsshare
```


```bash
systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
```

Now we will share the NFS directory over the network a follows:

vim /etc/exports
We will make two sharing points  /home and /var/nfsshare. Edit the exports file as follows:

```text
/var/nfsshare    192.168.0.101(rw,sync,no_root_squash,no_all_squash)
/home            192.168.0.101(rw,sync,no_root_squash,no_all_squash)
```

Note 192.168.0.101 is the IP of the client machine, if you wish that any other client should access it you need to add it IP wise otherwise you can add "*" instead of IP for all IP access.

```text
/var/nfsshare    *(rw,sync,no_root_squash,no_all_squash)
/home            *(rw,sync,no_root_squash,no_all_squash)
```


```bash
systemctl restart nfs-server
```

```bash
firewall-cmd --permanent --zone=public --add-service=nfs
firewall-cmd --permanent --zone=public --add-service=mountd
firewall-cmd --permanent --zone=public --add-service=rpc-bind
firewall-cmd --reload
```



[root@vb0634 ~]# ss -tulpn | grep 2049

```text
udp    UNCONN     0      0         *:2049                  *:*
udp    UNCONN     0      0      [::]:2049               [::]:*
tcp    LISTEN     0      64        *:2049                  *:*
tcp    LISTEN     0      64     [::]:2049               [::]:*
```

```bash
mkdir /nfs
mkdir /nfs/marc1
sudo chown -R 8536:8536 /nfs
# Can restrict to specific subnet instead of *
echo "/nfs *(rw,sync,no_root_squash,no_all_squash,async,no_subtree_check)" >> /etc/exports
exportfs -a
systemctl restart nfs-server
# Mount path <IP>:/nfs can be used (1 file-system per workspace)

mkdir /nfs/${WORKSPACE_NAME}
sudo chown 8536:8536 /nfs
# Mount path <IP>:/nfs/${WORKSPACE_NAME} can be used (1 directory per workspace)
```

NFS client:

```bash
yum -y install nfs-utils
mkdir -p /mnt/nfs/home
mkdir -p /mnt/nfs/var/nfsshare
```

```bash
mount -t nfs 10.17.197.26:/home /mnt/nfs/home/
mount -t nfs 10.17.197.26:/var/nfsshare /mnt/nfs/var/nfsshare/
```


[root@vb0636 ~]# df -kh
```text
....
10.17.197.26:/home          1.5T  5.7G  1.5T   1% /mnt/nfs/home
10.17.197.26:/var/nfsshare  2.2T  131G  2.1T   6% /mnt/nfs/var/nfsshare
```

touch /mnt/nfs/var/nfsshare/test_nfs


## Permanent NFS mounting

vim /etc/fstab
Add the entries like this:

```text
10.17.197.26:/home    /mnt/nfs/home   nfs defaults 0 0
10.17.197.26:/var/nfsshare    /mnt/nfs/var/nfsshare   nfs defaults 0 0
```

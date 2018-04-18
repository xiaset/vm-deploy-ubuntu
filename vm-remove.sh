#!/bin/bash
virsh destroy $1
virsh undefine $1
virsh vol-delete --pool shared $1-disk0

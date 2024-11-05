# hyperv
# Ansible Module - xray700r.hyperv

[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)


# xray700r.hyperv

This collection provides a range of modules for managing Hyper-V hosts and VM's etc that run on those hosts.

**Note:** This is a work in progress and it is actually being developed. Any problems, issues, bugs that are identified are gradually solved during the development and testing.

## Ansible Requirements

The collection and playbooks are developed and tested with [versions](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html) of Ansible core (higher than `2.12`).

The library of scripts is based on the support for powershell by ansible core [powershell by ansible core](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-core-target-node-powershell-and-windows-support)

## Installation

The collection and related playbooks can be installed by cloning this repo. 

## Preparation of target HyperV hosts

On target machine run: https://github.com/ansible/ansible/blob/devel/examples/scripts/ConfigureRemotingForAnsible.ps1
On ansible controller machine run: pip install pywinrm

## Platforms

The collection has been tested with the Hyper-V role based VMs on:

```yaml
Windows Server:
  - 2016
  - 2019
  - 2022
```

## Sample Playbooks


| Name | Description |
| ---- | ----------- |
| **Create VM** | Create a Hyper-V VM |
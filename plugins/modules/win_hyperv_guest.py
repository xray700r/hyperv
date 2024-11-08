#!/usr/bin/python
# -*- coding: utf-8 -*-
# This is a windows documentation stub. actual code lives in the .ps1
# file of the same name

DOCUMENTATION = '''
---
module: win_hyperv_guest
version_added: "2.4"
short_description: Adds, deletes and performs power functions on Hyper-V VM's.
description:
    - Adds, deletes and performs power functions on Hyper-V VM's.
options:
  name:
    description:
      - Name of VM
    required: true
  state:
    description:
      - State of VM
    required: false
    choices:
      - present
      - absent
	  - started
	  - stopped
    default: present
  memory:
    description:
      - Sets the amount of memory for the VM.
    required: false
    default: 512MB
  hostserver:
    description:
      - Server to host VM
    required: false
    default: null
  generation:
    description:
      - Specifies the generation of the VM
    required: false
    default: 2
  network_switch:
    description:
      - Specifies a network adapter for the VM
    required: false
    default: null
  diskpath:
    description:
      - Specify path of VHD/VHDX file for VM
	  - If the file exists it will be attached, if not then a new one will be created
    require: false
    default: null
'''

EXAMPLES = '''
  # Create VM
  win_hyperv_guest:
    name: Test

  # Delete a VM
  win_hyperv_guest:
    name: Test
	state: absent

  # Create VM with 256MB memory
  win_hyperv_guest:
    name: Test
	memory: 256MB

  # Create generation 1 VM with 256MB memory and a network adapter
  win_hyperv_guest:
    name: Test
    generation: 1
    memory: 256MB
    network_switch: WAN1
'''

ANSIBLE_METADATA = {
    'status': ['preview'],
    'supported_by': 'community',
    'metadata_version': '1.1'
}

#!/bin/bash
echo $(ip route | grep default | awk '{print $3}')

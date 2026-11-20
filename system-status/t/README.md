# Scheduled SMART discovery tests

Run `prove -lr system-status/t`. Perl::Critic enables lint checks for the added tests.
The tests use real collector functions with mock SMART, CPU and disk-space
providers; they never query real disks. They cover disk-only selection, passthrough,
discovery-error reporting, continued CPU/disk-space collection, empty inventory and
the temperature override. Merge fdisk's disk-only/error-reference API and the
smart-status forwarding change before this scheduled caller change.

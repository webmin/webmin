# SMART discovery tests

Run `prove -lr smart-status/t`. Perl::Critic enables lint checks for the added tests.
The disk-discovery test mocks the fdisk provider and controller helpers; it never
queries real disks. It covers option/error propagation, configured and detected
RAID members, manual fallback after provider/controller failure, fatal failure
without a usable fallback, duplicate identity, fresh provider results, empty inventory and the
ordinary ST9750420AS model. The disk-only/error-reference fdisk API must be merged
before this module's option is used for scheduled collection.

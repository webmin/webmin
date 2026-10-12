# Disk-only discovery tests

Run `prove -lr fdisk/t`. Perl::Critic enables lint checks for the added tests.
Fixtures use temporary kernel/device trees and fake partition commands; they
never query real disks. Coverage includes GPT/MBR, fdisk fallback, cache isolation,
fresh inventory and identifiers, disappearance, invalid/empty inventory, and
non-throwing error reporting. Physical RAID and real hotplug need hardware tests.

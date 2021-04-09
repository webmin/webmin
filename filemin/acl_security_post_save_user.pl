use strict;
use warnings;

do 'filemin-lib.pl';

our (%in);

sub acl_security_post_save_user
{
my ($mod, $user, $acls) = @_;
my $uconfig_directory;
if (&foreign_installed("usermin")) {
    &foreign_require("usermin");
    my %uminiserv;
    &usermin::get_usermin_miniserv_config(\%uminiserv);
    $uconfig_directory = $uminiserv{'env_WEBMIN_CONFIG'};
    }

# Check for main config directory
if (!-d $uconfig_directory) {
    return;
    }
# Check for module config directory
elsif (!-d "$uconfig_directory/$mod") {
    mkdir("$uconfig_directory/$mod", 0755);
    }

# ACL file
my $aclfile = "$uconfig_directory/$mod/$user.acl";

# Save ACLs file
if ($acls) {
    return if (!$in{'save_usermin_acls'});
    &lock_file($aclfile);
    &write_file($aclfile, $acls);
    &set_ownership_permissions(undef, undef, 0640, $aclfile);
    &unlock_file($aclfile);
    }
# Delete ACLs file
else {
    &unlink_file($aclfile);
    }
}

1;

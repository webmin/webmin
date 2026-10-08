# Common functions for the xterm module

BEGIN { push(@INC, ".."); };    ## no critic
use WebminCore;
use strict;
use warnings;
no warnings 'uninitialized';
our (%access, %config);
init_config();
%access = get_module_acl();

# config_pre_load(mod-info-ref, [mod-order-ref])
# Check if some config options are conditional,
# and if not allowed, remove them from listing
sub config_pre_load
{
my ($modconf_info, $modconf_order) = @_;
if (($ENV{'HTTP_X_REQUESTED_WITH'} || '') eq "XMLHttpRequest") {
	# Size is not supported in Authentic, because resize works flawlessly
	# and making it work would just add addition complexity for no good
	# reason
	delete($modconf_info->{'size'}) if (ref($modconf_info) eq 'HASH');
	@{$modconf_order} = grep { $_ ne 'size' } @{$modconf_order}
		if (ref($modconf_order) eq 'ARRAY');
	}
}

# get_terminal_options([theme])
# Return xterm.js color options for a Dark or Light scheme. Missing or
# unrecognized names use Dark, preserving the default for older installs.
# Auto starts with Dark until the client resolves the page color scheme.
sub get_terminal_options
{
my ($theme) = @_;
if ($theme ne 'light') {
	# Keep xterm.js defaults for the dark palette and text contrast.
	return { 'theme' => { 'background' => '#000000',
	                     'foreground' => '#ffffff' },
	         'minimumContrastRatio' => 1 };
	}

# Darker ANSI colors and contrast adjustment keep light terminals readable.
return {
	'theme' => {
		'background' => '#ffffff', 'foreground' => '#242424',
		'cursor' => '#242424', 'cursorAccent' => '#ffffff',
		'selectionBackground' => '#add6ff',
		'selectionInactiveBackground' => '#d0d0d0',
		'black' => '#242424', 'red' => '#a31515', 'green' => '#256c18',
		'yellow' => '#795e00', 'blue' => '#0451a5', 'magenta' => '#7a287d',
		'cyan' => '#007070', 'white' => '#bfbfbf',
		'brightBlack' => '#666666', 'brightRed' => '#b52020',
		'brightGreen' => '#287028', 'brightYellow' => '#806000',
		'brightBlue' => '#005cc5', 'brightMagenta' => '#8b298f',
		'brightCyan' => '#007575', 'brightWhite' => '#ffffff',
		},
	'minimumContrastRatio' => 4.5,
	};
}

# get_terminal_theme_script(theme)
# Return the initial Auto palette and its change listener for #terminal.
# Clients pass their xterm.js instance to the container's xtermTheme function
# and call xtermTheme.dispose() when the connection closes.
sub get_terminal_theme_script
{
my ($theme) = @_;
return '' if ($theme ne 'auto');
my $themes_json = convert_to_json({
    'dark' => get_terminal_options('dark'),
    'light' => get_terminal_options('light'),
    });
return <<EOF;
<script>
(function() {
    const termcont = document.getElementById('terminal'),
          root = document.documentElement,
          themes = $themes_json,
          schemeQuery = window.matchMedia('(prefers-color-scheme: dark)');
    let terminal;
    // Keep the loading surface and renderer on the same palette.
    const update = function() {
        const pageScheme = getComputedStyle(document.body).colorScheme,
              background = root.getAttribute('data-bgs'),
              mode = background ? (background === 'nightRider' ? 'dark' : 'light') :
                  (pageScheme === 'dark' || pageScheme === 'light' ? pageScheme :
                   (schemeQuery.matches ? 'dark' : 'light')),
              colors = themes[mode];
        if (terminal) {
            terminal.options.theme = colors.theme;
            terminal.options.minimumContrastRatio = colors.minimumContrastRatio;
        }
        termcont.setAttribute('data-terminal-theme', mode);
        termcont.style.setProperty('--terminal-background', colors.theme.background);
        termcont.style.setProperty('--terminal-foreground', colors.theme.foreground);
    };
    // xtermTheme(term) attaches the renderer after the loading colors are set.
    termcont.xtermTheme = function(term) { terminal = term; update(); };
    const observer = new MutationObserver(update),
          observeOptions = { attributes: true,
              attributeFilter: ['data-bgs', 'data-scheme', 'class', 'style'] };
    observer.observe(root, observeOptions);
    observer.observe(document.body, observeOptions);
    schemeQuery.addEventListener('change', update);
    // dispose() stops palette notifications after disconnect or a theme takeover.
    termcont.xtermTheme.dispose = function() {
        observer.disconnect();
        schemeQuery.removeEventListener('change', update);
        terminal = null;
    };
    update();
})();
</script>
EOF
}

# verify_websocket_key(client-key, session-id)
# Returns 1 if the client's Sec-WebSocket-Key matches the base64-encoded
# session ID, 0 otherwise. miniserv.pl rewrites the inbound handshake key
# to base64(session_id) before forwarding the upgrade to the shell server,
# so equality proves the connection came through the authenticated proxy
# and is bound to this Webmin session.
sub verify_websocket_key
{
my ($key, $sess) = @_;
return 0 if (!defined($key) || !defined($sess) || $sess eq '');
require MIME::Base64;
my $dsess = MIME::Base64::encode_base64($sess);
$key   =~ s/\s//g;
$dsess =~ s/\s//g;
return 0 if ($key eq '' || $dsess eq '');
return $key eq $dsess ? 1 : 0;
}

# parse_resize_message(message)
# If $message is the resize signal that xterm.js sends on terminal resize
# (literal backslash-zero-three-three then "[8;(rows);(cols)t"), return
# (rows, cols) as integers. Otherwise return an empty list. The format is
# a custom out-of-band signal — not a real ANSI escape — so anything else
# is treated as regular keyboard input and forwarded to the shell.
sub parse_resize_message
{
my ($msg) = @_;
return () if (!defined($msg));
if ($msg =~ /^\\033\[8;\((\d+)\);\((\d+)\)t\z/) {
	return ($1 + 0, $2 + 0);
	}
return ();
}

# resolve_shell_user(\%access, $remote_user, \%in, \%config)
# Decide which Unix account the terminal will run as, given the module ACL
# (%access), the Webmin-authenticated user, the CGI input (%in, which may
# carry a 'user' override) and the module config (%config). Pure function:
# does no I/O beyond getpwnam() for the sudoenforce branch. The caller
# must still validate the result against getpwnam() before exec'ing a shell.
#
# Rules (preserved verbatim from the previous inline version in index.cgi):
#   - access user "*" → start from $remote_user.
#   - else, access user "root" with sudoenforce !=0 AND no explicit
#     in{user} AND remote_user differs from "root" → prefer remote_user
#     when it has a local home dir (sudo-preferred path).
#   - config{user} can override a remaining "root" choice.
#   - if the resolved user is still "root" AND in{user} is set, in{user}
#     overrides — the admin explicitly allowed root, so any user is OK.
# Note the trailing in{user} branch runs regardless of how $user got to
# "root", so e.g. access="*" with remote_user="root" can still be
# overridden by in{user}. That's preserved here for compatibility; an
# operator who wants in{user} ignored for "*" should ensure the
# authenticated user isn't root.
sub resolve_shell_user
{
my ($access, $remote_user, $in, $config) = @_;
$in     ||= {};
$config ||= {};
my $user = $access->{'user'};
return if (!defined($user) || $user eq '');
if ($user eq "*") {
	$user = $remote_user;
	}
elsif ($user eq "root" && $remote_user ne $user && !$in->{'user'} &&
       (defined($access->{'sudoenforce'}) ? $access->{'sudoenforce'} : '') ne '0') {
	my @uinfo = getpwnam($remote_user);
	if (@uinfo && $uinfo[7]) {
		$user = $remote_user;
		}
	}
$user = $config->{'user'} if ($user eq 'root' && $config->{'user'});
if ($user eq "root" && defined($in->{'user'}) && $in->{'user'} ne '') {
	$user = $in->{'user'};
	}
return $user;
}

1;
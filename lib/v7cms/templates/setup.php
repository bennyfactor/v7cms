<?php
/**
 * One-time setup script for v7cms production deployment
 *
 * This script:
 * 1. Detects the correct Ruby path
 * 2. Updates the shebang in index.fcgi
 * 3. Sets correct file permissions
 * 4. Deletes itself
 *
 * Usage: Visit https://yourdomain.com/setup.php in your browser after deployment
 */

// Prevent running this in development
if (getenv('RACK_ENV') === 'development' || file_exists('.env.development')) {
    die('This setup script should only be run in production environments.');
}

$output = [];
$errors = [];

// Function to add output message
function add_output($message, $type = 'info') {
    global $output;
    $output[] = ['type' => $type, 'message' => $message];
}

// Function to add error
function add_error($message) {
    global $errors;
    $errors[] = $message;
}

// Step 1: Detect Ruby path
add_output('Detecting Ruby path...', 'info');

// Detect the home directory - script may run as Apache user, not file owner
$home_dir = null;
$script_dir = __DIR__;

// Try to extract username from path like /home/username/...
if (preg_match('#^/home/([^/]+)/#', $script_dir, $matches)) {
    $username = $matches[1];
    $home_dir = "/home/$username";
    add_output("Detected user from path: $username", 'info');
    add_output("Using home directory: $home_dir", 'info');
} else {
    // Fallback to HOME environment variable
    $home_dir = getenv('HOME');
    if ($home_dir) {
        add_output("Using HOME environment variable: $home_dir", 'info');
    } else {
        add_output("Could not detect home directory", 'error');
    }
}

// Try to find rbenv Ruby first
$ruby_path = null;
$desired_version = null;
$found_version = null;

// Check for .ruby-version file
$ruby_version_file = '.ruby-version';
if (file_exists($ruby_version_file)) {
    $desired_version = trim(file_get_contents($ruby_version_file));
    add_output("Found .ruby-version: $desired_version", 'info');

    if ($home_dir && is_dir("$home_dir/.rbenv/versions")) {
        // Try exact version match first
        $rbenv_ruby = "$home_dir/.rbenv/versions/$desired_version/bin/ruby";
        if (file_exists($rbenv_ruby)) {
            $ruby_path = $rbenv_ruby;
            $found_version = $desired_version;
            add_output("Found exact version match: $ruby_path", 'success');
        } else {
            // Try to find compatible version (same major.minor)
            $desired_parts = explode('.', $desired_version);
            $desired_major_minor = isset($desired_parts[0], $desired_parts[1])
                ? $desired_parts[0] . '.' . $desired_parts[1]
                : null;

            if ($desired_major_minor) {
                add_output("Exact version not found, looking for compatible $desired_major_minor.x versions...", 'info');

                $versions = scandir("$home_dir/.rbenv/versions");
                $compatible_versions = [];

                foreach ($versions as $version) {
                    if ($version === '.' || $version === '..') continue;
                    if (strpos($version, $desired_major_minor) === 0) {
                        $test_ruby = "$home_dir/.rbenv/versions/$version/bin/ruby";
                        if (file_exists($test_ruby)) {
                            $compatible_versions[] = $version;
                        }
                    }
                }

                if (!empty($compatible_versions)) {
                    // Sort versions and pick the latest compatible one
                    usort($compatible_versions, 'version_compare');
                    $found_version = end($compatible_versions);
                    $ruby_path = "$home_dir/.rbenv/versions/$found_version/bin/ruby";
                    add_output("Found compatible version: $found_version", 'success');

                    if ($found_version !== $desired_version) {
                        add_output("Using $found_version instead of $desired_version", 'info');
                    }
                }
            }
        }
    }
}

// Fallback: Try rbenv shims
if (!$ruby_path && $home_dir) {
    $rbenv_shim = "$home_dir/.rbenv/shims/ruby";
    if (file_exists($rbenv_shim)) {
        // Resolve the actual Ruby path from the shim
        $ruby_path = trim(shell_exec("$rbenv_shim -e 'puts RbConfig.ruby' 2>/dev/null"));
        if ($ruby_path && file_exists($ruby_path)) {
            add_output("Found Ruby via rbenv shim: $ruby_path", 'success');
        } else {
            $ruby_path = null;
        }
    }
}

// Last resort: Use which ruby (but warn if it's system Ruby)
if (!$ruby_path) {
    $ruby_path = trim(shell_exec('which ruby 2>/dev/null'));
    if ($ruby_path && file_exists($ruby_path)) {
        if (strpos($ruby_path, '.rbenv') === false) {
            add_output("WARNING: Using system Ruby at $ruby_path (not rbenv)", 'error');
            add_output("This may not be the correct Ruby version", 'error');
        } else {
            add_output("Found Ruby at: $ruby_path", 'success');
        }
    }
}

if (empty($ruby_path) || !file_exists($ruby_path)) {
    add_error('Could not find Ruby. Please ensure Ruby is installed and accessible.');

    if ($desired_version) {
        add_error("To install Ruby $desired_version with rbenv, run:");
        add_error("  rbenv install $desired_version");
        add_error("  rbenv rehash");
    }
} else {
    // Verify it's an rbenv Ruby
    if (strpos($ruby_path, '.rbenv') !== false) {
        add_output('Detected rbenv-managed Ruby ✓', 'success');
    }

    // Get Ruby version
    $ruby_version = trim(shell_exec("$ruby_path --version 2>/dev/null"));
    add_output("Ruby version: $ruby_version", 'info');
}

// Step 1.5: Update .ruby-version if using compatible patch version
if (!empty($found_version) && !empty($desired_version) && $found_version !== $desired_version) {
    // Verify they only differ in patch version
    $found_parts = explode('.', $found_version);
    $desired_parts = explode('.', $desired_version);

    $same_major = isset($found_parts[0], $desired_parts[0]) && $found_parts[0] === $desired_parts[0];
    $same_minor = isset($found_parts[1], $desired_parts[1]) && $found_parts[1] === $desired_parts[1];

    if ($same_major && $same_minor) {
        // Only patch version differs - safe to update .ruby-version
        add_output("Updating .ruby-version to match available Ruby...", 'info');

        if (file_put_contents($ruby_version_file, $found_version . "\n") !== false) {
            add_output("Updated .ruby-version from $desired_version to $found_version", 'success');
        } else {
            add_output("Could not update .ruby-version (non-critical)", 'error');
        }
    }
}

// Step 2: Update index.fcgi shebang
if (empty($errors) && file_exists('index.fcgi')) {
    add_output('Updating index.fcgi shebang...', 'info');

    $fcgi_content = file_get_contents('index.fcgi');
    if ($fcgi_content === false) {
        add_error('Could not read index.fcgi');
    } else {
        // Replace the shebang line (first line)
        $lines = explode("\n", $fcgi_content);
        $old_shebang = $lines[0];
        $lines[0] = "#!$ruby_path";
        $new_content = implode("\n", $lines);

        // Write back to file
        if (file_put_contents('index.fcgi', $new_content) === false) {
            add_error('Could not write to index.fcgi - check file permissions');
        } else {
            add_output("Updated shebang from: $old_shebang", 'info');
            add_output("Updated shebang to: #!$ruby_path", 'success');
        }
    }
}

// Step 3: Set permissions
if (empty($errors)) {
    add_output('Setting file permissions...', 'info');

    if (chmod('index.fcgi', 0755)) {
        add_output('Set index.fcgi to executable (0755) ✓', 'success');
    } else {
        add_error('Could not set index.fcgi permissions');
    }
}

// Step 4: Verify setup
if (empty($errors)) {
    add_output('Verifying setup...', 'info');

    // Check if index.fcgi is executable
    if (is_executable('index.fcgi')) {
        add_output('index.fcgi is executable ✓', 'success');
    } else {
        add_error('index.fcgi is not executable');
    }

    // Check .env file exists
    if (file_exists('.env')) {
        add_output('.env file found ✓', 'success');

        // Check ADMIN_EMAILS configuration
        $env_content = file_get_contents('.env');
        if (preg_match('/^ADMIN_EMAILS=(.+)$/m', $env_content, $matches)) {
            $admin_emails_raw = trim($matches[1]);
            if (!empty($admin_emails_raw)) {
                $admin_emails = array_map('trim', explode(',', $admin_emails_raw));
                $count = count($admin_emails);
                add_output("ADMIN_EMAILS configured ✓ ($count authorized admin" . ($count === 1 ? '' : 's') . ")", 'success');
                add_output("Authorized emails: " . implode(', ', $admin_emails), 'info');
            } else {
                add_error('ADMIN_EMAILS is set but empty - admin login will be DISABLED');
            }
        } else {
            add_error('ADMIN_EMAILS not found in .env - admin login will be DISABLED');
            add_error('Add to .env: ADMIN_EMAILS=your-email@example.com');
        }
    } else {
        add_error('.env file not found - you will need to create it with OAuth credentials');
    }
}

// Step 5: Delete this setup script if everything succeeded
$self_deleted = false;
if (empty($errors)) {
    add_output('Setup completed successfully!', 'success');
    add_output('Deleting setup.php...', 'info');

    if (unlink(__FILE__)) {
        $self_deleted = true;
        add_output('setup.php deleted ✓', 'success');
    } else {
        add_error('Could not delete setup.php - please delete it manually for security');
    }
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>v7cms Production Setup</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 700px;
            width: 100%;
            padding: 40px;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .message {
            padding: 12px 16px;
            margin: 10px 0;
            border-radius: 6px;
            font-size: 14px;
            line-height: 1.5;
        }
        .message.info {
            background: #e3f2fd;
            color: #1565c0;
            border-left: 4px solid #1976d2;
        }
        .message.success {
            background: #e8f5e9;
            color: #2e7d32;
            border-left: 4px solid #43a047;
        }
        .message.error {
            background: #ffebee;
            color: #c62828;
            border-left: 4px solid #e53935;
        }
        .section {
            margin: 30px 0;
        }
        .section h2 {
            color: #555;
            font-size: 18px;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 2px solid #eee;
        }
        .status {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 14px;
            margin: 20px 0;
        }
        .status.success {
            background: #4caf50;
            color: white;
        }
        .status.error {
            background: #f44336;
            color: white;
        }
        .next-steps {
            background: #f5f5f5;
            padding: 20px;
            border-radius: 8px;
            margin-top: 30px;
        }
        .next-steps h3 {
            color: #333;
            margin-bottom: 15px;
            font-size: 16px;
        }
        .next-steps ol {
            margin-left: 20px;
            color: #555;
        }
        .next-steps li {
            margin: 8px 0;
            line-height: 1.6;
        }
        code {
            background: #263238;
            color: #aed581;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 13px;
            font-family: 'Monaco', 'Courier New', monospace;
        }
        .warning {
            background: #fff3cd;
            border: 1px solid #ffc107;
            padding: 15px;
            border-radius: 6px;
            margin: 20px 0;
            color: #856404;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 v7cms Production Setup</h1>
        <p class="subtitle">One-time configuration script</p>

        <?php if (empty($errors)): ?>
            <div class="status success">✓ Setup Completed Successfully</div>
        <?php else: ?>
            <div class="status error">✗ Setup Failed</div>
        <?php endif; ?>

        <div class="section">
            <h2>Setup Log</h2>
            <?php foreach ($output as $msg): ?>
                <div class="message <?php echo htmlspecialchars($msg['type']); ?>">
                    <?php echo htmlspecialchars($msg['message']); ?>
                </div>
            <?php endforeach; ?>

            <?php foreach ($errors as $error): ?>
                <div class="message error">
                    ✗ ERROR: <?php echo htmlspecialchars($error); ?>
                </div>
            <?php endforeach; ?>
        </div>

        <?php if ($self_deleted): ?>
            <div class="warning">
                <strong>⚠️ This page will not work if you refresh</strong><br>
                The setup.php file has been deleted for security. If you need to run setup again,
                you'll need to re-upload or recreate this file.
            </div>
        <?php endif; ?>

        <?php if (empty($errors)): ?>
            <div class="next-steps">
                <h3>✅ Next Steps</h3>
                <ol>
                    <li>Ensure your <code>.env</code> file contains OAuth credentials</li>
                    <li>Visit your site: <a href="/">Homepage</a></li>
                    <li>Visit the admin panel: <a href="/admin.html">Admin</a></li>
                    <li>Test OAuth login with Google or GitHub</li>
                    <li>Create your first blog post</li>
                </ol>
            </div>
        <?php else: ?>
            <div class="next-steps">
                <h3>⚠️ Manual Steps Required</h3>
                <ol>
                    <li>SSH into your server</li>
                    <li>Fix the errors listed above</li>
                    <li>Re-run this setup by visiting <code>/setup.php</code> again</li>
                </ol>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>

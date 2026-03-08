import os
import re
import sys
import subprocess
from datetime import datetime

LOG_NAME = 'release'

def log_info(message):
    print(f"INFO [{LOG_NAME}]: {message}")

def log_error(message):
    print(f"ERROR [{LOG_NAME}]: {message}", file=sys.stderr)

def get_process_output(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        # Ignore errors for git describe as it might fail if no tags exist
        if args[0] == 'git' and args[1] == 'describe':
            return ""
        log_error(f"Command failed: {' '.join(args)}\n{e.stderr}")
        return ""

def parse_git_log_output(raw):
    entries = []
    blocks = raw.split('<<END>>')
    for block in blocks:
        trimmed = block.strip()
        if not trimmed:
            continue
        lines = trimmed.split('\n')
        if not lines:
            continue
        commit_hash = lines[0].strip()
        message = '\n'.join(lines[1:]).strip()
        
        if not commit_hash and not message:
            continue
            
        entries.append({'hash': commit_hash, 'message': message})
    return entries

def read_commits(last_tag):
    args = ['git', 'log', '--pretty=format:%h%n%B%n<<END>>', '--no-merges']
    if last_tag:
        args.append(f'{last_tag}..HEAD')
        
    output = get_process_output(args)
    return parse_git_log_output(output)

def format_commit_messages(commits, include_hashes=True):
    if not commits:
        return '- No changes detected (or git error).'
        
    formatted = []
    for commit in commits:
        message_lines = commit['message'].split('\n')
        subject = message_lines[0] if message_lines and message_lines[0] else '(no commit message)'
        hash_suffix = f" ({commit['hash']})" if include_hashes else ""
        
        buffer = [f"- {subject}{hash_suffix}"]
        
        if len(message_lines) > 1:
            for line in message_lines[1:]:
                buffer.append(f"  {line}" if line.strip() else "  ")
                
        formatted.append('\n'.join(buffer))
        
    return '\n'.join(formatted)

def main():
    log_info('🔃 Starting release process...')
    
    project_file = 'project.yml'
    changelog_file = 'CHANGELOG.md'
    
    if not os.path.exists(project_file):
        log_error(f'❌ Error: {project_file} not found.')
        sys.exit(1)
        
    # Ensure CHANGELOG exists
    if not os.path.exists(changelog_file):
        with open(changelog_file, 'w') as fh:
            fh.write('# Changelog\n\n')

    with open(project_file, 'r') as fh:
        project_content = fh.read()
        
    market_match = re.search(r'MARKETING_VERSION:\s*([\d.]+)', project_content)
    build_match = re.search(r'CURRENT_PROJECT_VERSION:\s*(\d+)', project_content)
    
    if not market_match:
        log_error('❌ Error: Could not find MARKETING_VERSION in project.yml')
        sys.exit(1)
        
    current_version_name = market_match.group(1)
    current_build_number = build_match.group(1) if build_match else '1'
    
    log_info(f'ℹ️ Current version: {current_version_name}+{current_build_number}')
    
    # Calculate next version - keeping current for now as in original script
    next_version_name = current_version_name
    next_build_number = current_build_number
    next_full_version = f'{next_version_name}+{next_build_number}'
    
    log_info(f'🚀 Next version: {next_full_version}')
    
    log_info('📝 Generating Content...')
    
    last_tag = get_process_output(['git', 'describe', '--tags', '--abbrev=0'])
    if last_tag:
        log_info(f'   Last tag: {last_tag}')
    else:
        log_info('   No previous tags found. listing all commits.')
        
    raw_commits = read_commits(last_tag)
    commits_for_changelog = format_commit_messages(raw_commits, include_hashes=True)
    
    today = datetime.now()
    date_str = today.strftime('%Y-%m-%d')
    
    changelog_entry = f"## [{next_full_version}] - {date_str}\n{commits_for_changelog}\n\n"
    
    # Update CHANGELOG.md
    with open(changelog_file, 'r') as f:
        current_changelog = f.read()
        
    if '# Changelog' in current_changelog:
        updated_changelog = current_changelog.replace('# Changelog', f'# Changelog\n\n{changelog_entry}', 1)
    else:
        updated_changelog = f'# Changelog\n\n{changelog_entry}{current_changelog}'
        
    with open(changelog_file, 'w') as f:
        f.write(updated_changelog)
    log_info('✅ Updated CHANGELOG.md')
    
    log_info(f'🎉 Release preparation complete! Version bumped to {next_version_name}+{next_build_number}')

if __name__ == '__main__':
    main()

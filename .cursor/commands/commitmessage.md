Create commit messsage for staged content,
create both message and description if neccessary, for example if change is big or some notes that don't fit in message.
use git log to see last 50 full commit messages
git log -50 --format="%s%n%b---"
don't modify or create any file

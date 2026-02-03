# Initial commit

File Creation

## 0.1 
implement(app): Added rich text support, added formatting keybinds in "Format" header. Fixed storyboard layout to have notes view vertical and alternating colors. Added tag support into note url call as well as date modified. Edited mainview to reflect changes. Made user select folder on each launch

fixes(app): - fixed search func overriding create note func, fixed note view flashing the folder contents when typing in note body of a recently made or recently accessed note, fixed file manager writes rich text by default, fixed rich text string names showing as note titles after modifying note contents

update:styling applied aqua across entire application, more akin to nvALT and and pre-bigsur

added:context menu on right click and all functionality integrated

fixes:app  fixed deleting files or converting to .txt instead of .rtf, fixed tag renaming note to first line of text in file, fixed title app

## 0.2 
update:styling applied to settings and columns to fit styling of nvALT more

add:qol column resizing, size to fit for beauty standards

fix:lag when double clicking tag cell , laggy population of note body when resizing editor scene.

add:sorting in note scene (columns), sorting icon (arrow), features to "File" in menu bar (changed "File" -> "Notation", Printing, Editor Func. like undo, redo, etc.

update:mainview "Window" -> nvSIL

bugfixes -> Column resizing issue (extending past window, collapsing text), RTF syntax not applying to file and only in editor scene preview, tag modification changes date modified (useful when sorting)

## 0.3
Added WikiLink style note linking! 
Multiple Bug fixes
 
## 0.4
Disabled dark mode (sorry tiktok kiddies)

Normal text formatting reenabled (disabled after editor refactor bug that was fixed)

Menu bar icon added

Added "Make URL's clickable links" func.

Removed "Use nvALT scroll bars" from settings

## 0.5 

Fixed deleting or renaming a file reseting currently applied sort method

Implemented Undo & Redo func.

Search bar updates when file is renamed

Fixed editor undoing changes to file contents after metadata change (tag, date modified, location move, etc.)

## 0.6

Deleted files now go to trash

Fixed sorting (ascending and descending)

Ensured "Date Modified" directly reflected system "Date Modified"

Tag search implemented (typing "#" into the search bar)
Added HotkeyManager, fixing "Bring app to front hotkey" (carbon API)

Fixed highlight font color change in note scene upon clicking a different note

## 0.7

Removed ability to read and show anything but rtf files

Removed placeholder storyboard windows for renaming and tagging files, implemented simple highlighted and typable cell option
Add: (SuggestionPopupController) Auto suggest for tag and wikilinks ([[ ->suggest)

Add: nv keybinds (hand full non-functional, fixing on 0.9.9)

## 0.8 

Add: Ability to pin note to top of list in note scene
Sort indicator logic cleanup & redundancy check

Fix quit when closing window

Remove soft tabs option from settings

Fix auto pair brackets/quotes

## 0.9

Fix editing settings window layout cutoff

Fix search highlight in note titles

## 1.0 (Release)

Removed URL to markdown import (will tackle at a later date)
Add: App icon, app category, menu bar icon uses app icon

Add: Tag Filtering by clicking on a tag

Add: Keyboard Shortcuts Note

Update: Startup notes ("Welcome To nvSIL!" & "Useful Shortcuts!")

# Where browser extension

Save the page you're on to Where — with a title, a note and a project.
Works in Chrome, Microsoft Edge, Brave, Opera and Vivaldi.

## Install

1. Run `start-where.bat` once. It copies this folder next to the Where app
   (`…\runner\Release\browser-extension`). You can also use this folder
   directly.
2. Open your browser's extensions page — `chrome://extensions`,
   `edge://extensions` or `brave://extensions` — and switch on
   **Developer mode**.
3. Click **Load unpacked** and choose the `browser-extension` folder.
4. Pin the Where button to the toolbar.
5. With Where open, click the button and then **Connect**. Where asks you to
   **Allow** the browser — you only do this once.

Where → Settings → Browser shows the same steps, the folder, and the
connected browsers (with Disconnect).

## Use

- **Click the Where button** (or press **Alt+Shift+W**): edit the title, add
  a note, choose a project, **Save** (or Ctrl+Enter). Saving a page that's
  already in Where updates it.
- **Right-click** a page → *Save page to Where*, or a link → *Save link to
  Where*. Existing notes are kept.

## Privacy

The extension only talks to the Where app on your own computer
(`http://127.0.0.1:47771`). It needs `activeTab` to read the current page's
title and address when you click it, `contextMenus` for the right-click
items, and `storage` to remember its connection. It never reads page
contents, your history, or anything in the background.

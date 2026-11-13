"use strict";

const repository = "https://github.com/acepleiades/SceneZOI";
const releaseApi = "https://api.github.com/repos/acepleiades/SceneZOI/releases/latest";
const version = document.getElementById("version");
const assetInfo = document.getElementById("asset-info");
const download = document.getElementById("download-link");
const label = document.getElementById("download-label");
const status = document.getElementById("release-status");
const releaseLink = document.getElementById("release-link");
const notes = document.getElementById("release-notes");
const extraDownloads = document.getElementById("extra-downloads");

// Render the Markdown used in release notes without inserting remote HTML.
function addInline(element, text) {
  const inline = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|(\x60[^\x60]+\x60)|\*\*([^*]+)\*\*/g;
  let offset = 0;
  for (const match of text.matchAll(inline)) {
    element.append(text.slice(offset, match.index));
    const part = document.createElement(match[1] ? "a" : match[3] ? "code" : "strong");
    if (match[1]) part.href = match[2];
    part.textContent = match[1] || (match[3] && match[3].slice(1, -1)) || match[4];
    element.append(part);
    offset = match.index + match[0].length;
  }
  element.append(text.slice(offset));
}

function showNotes(body) {
  if (!body?.trim()) return;
  notes.replaceChildren();
  let block;
  for (const line of body.trim().split(/\r?\n/)) {
    const heading = line.match(/^#{1,6}\s+(.+)/);
    const bullet = line.match(/^\s*[-*+]\s+(.+)/);
    const numbered = line.match(/^\s*\d+\.\s+(.+)/);
    if (!line.trim()) {
      block = null;
    } else if (bullet || numbered) {
      const type = bullet ? "ul" : "ol";
      if (block?.localName !== type) {
        block = document.createElement(type);
        notes.append(block);
      }
      const item = document.createElement("li");
      addInline(item, (bullet || numbered)[1]);
      block.append(item);
    } else if (heading) {
      const title = document.createElement("h3");
      addInline(title, heading[1]);
      notes.append(title);
      block = null;
    } else {
      if (block?.localName !== "p") {
        block = document.createElement("p");
        notes.append(block);
      } else {
        block.append(" ");
      }
      addInline(block, line);
    }
  }
}

async function loadRelease() {
  try {
    const response = await fetch(releaseApi, {
      headers: { Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(8000)
    });
    if (response.status === 404) {
      status.textContent = "No stable release is available yet.";
      return;
    }
    if (!response.ok) throw new Error("Release request failed");
    const release = await response.json();
    if (!release.tag_name || release.draft || release.prerelease) throw new Error("No stable release data");

    version.textContent = release.tag_name + " · Latest stable release";
    const details = repository + "/releases/tag/" + encodeURIComponent(release.tag_name);
    releaseLink.href = details;
    download.href = details;
    const assets = (release.assets || []).filter(asset =>
      asset.state === "uploaded" && /\.zip$/i.test(asset.name) &&
      asset.browser_download_url?.startsWith(repository + "/releases/download/")
    );
    const preferred = "SceneZOI-" + release.tag_name.replace(/^v/i, "") + ".zip";
    const primary = assets.find(asset => asset.name === preferred) || assets.find(asset => /^SceneZOI[-_.]/i.test(asset.name));

    if (primary) {
      download.href = primary.browser_download_url;
      label.textContent = "Download SceneZOI ZIP";
      assetInfo.textContent = new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 })
        .format(primary.size / 1000000) + " MB";
    } else {
      label.textContent = "View release on GitHub";
      status.textContent = "The latest release has no SceneZOI ZIP.";
    }
    for (const asset of assets.filter(asset => asset !== primary)) {
      const link = document.createElement("a");
      link.href = asset.browser_download_url;
      link.textContent = asset.name;
      extraDownloads.append(link);
    }
    extraDownloads.hidden = !extraDownloads.childElementCount;
    showNotes(release.body);
  } catch {
    status.textContent = "Live release details are unavailable. Open GitHub to find the latest ZIP.";
  }
}

loadRelease();

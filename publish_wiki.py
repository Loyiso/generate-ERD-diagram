"""
publish_wiki.py
Creates or updates an Azure DevOps wiki page via the REST API.

Usage:
    python publish_wiki.py \
        --org-url   "https://dev.azure.com/myorg/" \
        --project   "MyProject" \
        --page-path "/Database/ERD" \
        --content   /tmp/wiki-page.md \
        --token     "<PAT with Wiki Read & Write scope>"
"""
import argparse
import base64
import sys
import requests


def auth_header(pat: str) -> dict:
    token = base64.b64encode(f":{pat}".encode()).decode()
    return {
        "Authorization": f"Basic {token}",
        "Content-Type": "application/json",
    }


def wiki_base_url(org_url: str, project: str) -> str:
    org_url = org_url.rstrip("/")
    # Wiki identifier follows the convention <ProjectName>.wiki
    wiki_id = f"{project}.wiki"
    return f"{org_url}/{project}/_apis/wiki/wikis/{wiki_id}/pages"


def get_etag(session: requests.Session, base_url: str, page_path: str) -> str | None:
    resp = session.get(
        base_url,
        params={"path": page_path, "api-version": "7.1"},
    )
    if resp.status_code == 404:
        return None
    resp.raise_for_status()
    return resp.headers.get("ETag")


def upsert_page(
    session: requests.Session,
    base_url: str,
    page_path: str,
    content: str,
    etag: str | None,
):
    headers = {}
    if etag:
        headers["If-Match"] = etag

    resp = session.put(
        base_url,
        params={"path": page_path, "api-version": "7.1"},
        json={"content": content},
        headers=headers,
    )

    if resp.status_code not in (200, 201):
        print(f"Error {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)

    action = "updated" if etag else "created"
    print(f"Wiki page '{page_path}' {action}.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--org-url",   required=True, help="ADO org URL, e.g. https://dev.azure.com/myorg/")
    parser.add_argument("--project",   required=True, help="ADO project name")
    parser.add_argument("--page-path", required=True, help="Wiki page path, e.g. /Database/ERD")
    parser.add_argument("--content",   required=True, help="Path to markdown file with page content")
    parser.add_argument("--token",     required=True, help="PAT with Wiki Read & Write scope")
    args = parser.parse_args()

    with open(args.content, encoding="utf-8") as f:
        content = f.read()

    base_url = wiki_base_url(args.org_url, args.project)

    session = requests.Session()
    session.headers.update(auth_header(args.token))

    etag = get_etag(session, base_url, args.page_path)
    upsert_page(session, base_url, args.page_path, content, etag)


if __name__ == "__main__":
    main()

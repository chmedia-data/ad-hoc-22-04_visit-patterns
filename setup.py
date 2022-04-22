import os, sys, requests, subprocess
from github import Github
from datetime import datetime

def createRemoteRepo(repoPath):
    g = Github(login_or_token=os.environ['GITHUB_TOKEN'])
    org = g.get_organization('chmedia-data')
    repo = org.create_repo(repoPath)
    return repo

def addWebhook(repo):
    hook = repo.create_hook(
        name='web',
        events=['push'],
        config={
            "url": "https://kompass.chmedia.ch/ad-hoc/mirror",
            "content_type": "json",
            "secret": os.environ["KOMPASS_BASIC_PASS"]
    })

def addRemote(repo):
    subprocess.check_output(['git','remote','add','origin','git@github.com:'+repo.full_name+'.git'])

def getRepoPath():
    repoPath = os.getcwd().split('/')[-1]
    if not repoPath.startswith("ad-hoc"):
        repoPath = "ad-hoc-"+repoPath
    if not repoPath.startswith(f"ad-hoc-{datetime.now().strftime('%y')}-"):
        raise Exception("Invalid repo path format!")
    return repoPath

def addFolders():
    for dir in ["data","queries","docs"]:
        if not os.path.exists("./"+dir):
            os.mkdir(dir)

if __name__=='__main__':
    repoPath = getRepoPath()
    repo = createRemoteRepo(repoPath)
    addWebhook(repo)
    addRemote(repo)
    addFolders()

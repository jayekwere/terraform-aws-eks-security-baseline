#!/usr/bin/env python3
"""Run mock-only plans and inspect the composed upstream resources; never applies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
SUITES = {".": "secure_plan", "modules/namespace": "restricted_namespace",
          "modules/cluster-services": "dns_bootstrap", "modules/pod-identity": "bounded_reader"}


def source_manifest(root=ROOT):
    files = [p for p in root.rglob('*') if p.is_file() and
             not set(p.relative_to(root).parts) & {'.git', '.terraform', 'artifacts', '__pycache__'} and
             (p.suffix in {'.tf', '.hcl', '.py', '.yml', '.yaml', '.sh'} or p.name == 'requirements-ci.txt' or 'fixtures' in p.relative_to(root).parts)]
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}


def contract(plan, suite, root):
    rs = plan['resource_changes']
    def resources(kind):
        return [r['change']['after'] for r in rs if r['type'] == kind and r['mode'] == 'managed']
    def only(kind):
        vals = resources(kind)
        assert len(vals) == 1, (kind, len(vals))
        return vals[0]
    checks = {}
    if suite == '.':
        c = only('aws_eks_cluster')
        vpc = c['vpc_config'][0]
        checks['private-api'] = vpc['endpoint_private_access'] is True and vpc['endpoint_public_access'] is False
        checks['all-control-plane-logs'] = set(c['enabled_cluster_log_types']) == {'api','audit','authenticator','controllerManager','scheduler'}
        checks['explicit-access-only'] = c['access_config'][0] == {'authentication_mode':'API','bootstrap_cluster_creator_admin_permissions':False}
        checks['cluster-protection'] = c['deletion_protection'] is True and c['upgrade_policy'][0]['support_type'] == 'STANDARD'
        checks['no-extra-api-data-cmk'] = not c['encryption_config']
        policies = resources('aws_eks_access_policy_association')
        checks['scoped-viewer'] = len(policies) == 2 and any(p['policy_arn'].endswith('/AmazonEKSViewPolicy') and p['access_scope'][0] == {'type':'namespace','namespaces':['payments']} for p in policies)
        checks['one-explicit-admin'] = sum(p['access_scope'][0]['type'] == 'cluster' for p in policies) == 1 and any(p['principal_arn'] == 'arn:aws:iam::111122223333:role/bootstrap' and p['policy_arn'].endswith('/AmazonEKSClusterAdminPolicy') for p in policies)
        cni = next(p for p in resources('aws_eks_addon') if p['addon_name'] == 'vpc-cni')
        cfg = json.loads(cni['configuration_values'])
        checks['strict-network-policy'] = cfg.get('enableNetworkPolicy') == 'true' and cfg.get('env',{}).get('NETWORK_POLICY_ENFORCING_MODE') == 'strict'
        checks['cni-workload-role'] = len(cni['pod_identity_association']) == 1 and cni['pod_identity_association'][0]['service_account'] == 'aws-node'
        lt = only('aws_launch_template')
        checks['imdsv2-hop-one'] = lt['metadata_options'][0]['http_tokens'] == 'required' and lt['metadata_options'][0]['http_put_response_hop_limit'] == 1
        checks['encrypted-disk-no-ssh'] = not lt.get('key_name') and all(str(b['ebs'][0]['encrypted']).lower() == 'true' for b in lt['block_device_mappings'])
        nodes = [v for v in rs if v['address'].startswith('aws_iam_role_policy_attachment.nodes[')]
        checks['bounded-node-policies'] = {v['change']['after']['policy_arn'].split('/')[-1] for v in nodes} == {'AmazonEKSWorkerNodePolicy','AmazonEC2ContainerRegistryPullOnly'}
        key = only('aws_kms_key')
        checks['rotating-audit-key'] = key['enable_key_rotation'] is True and key['deletion_window_in_days'] == 30
        logs = only('aws_cloudwatch_log_group')
        checks['encrypted-audit-retention'] = logs['retention_in_days'] == 90 and logs['kms_key_id'] == key['arn']
        trust = json.loads(next(r for r in rs if r['address']=='aws_iam_role.cni')['change']['after']['assume_role_policy'])['Statement'][0]
        checks['exact-cni-trust'] = trust['Condition']['StringEquals'] == {'aws:RequestTag/eks-cluster-arn':'arn:aws:eks:us-west-2:111122223333:cluster/baseline-test','aws:RequestTag/kubernetes-namespace':'kube-system','aws:RequestTag/kubernetes-service-account':'aws-node'}
        checks['coredns-deferred'] = all(p['addon_name'] != 'coredns' for p in resources('aws_eks_addon'))
    elif suite == 'modules/namespace':
        ns = only('kubernetes_namespace_v1')['metadata'][0]['labels']
        checks['restricted-psa'] = all(ns.get('pod-security.kubernetes.io/'+mode) == 'restricted' and ns.get('pod-security.kubernetes.io/'+mode+'-version') == 'v1.35' for mode in ['enforce','warn','audit'])
        checks['no-api-token'] = only('kubernetes_service_account_v1')['automount_service_account_token'] is False
        policies = {p['metadata'][0]['name']:p['spec'][0] for p in resources('kubernetes_network_policy_v1')}
        deny = policies['default-deny']
        checks['bidirectional-deny'] = set(deny['policy_types']) == {'Ingress','Egress'} and not deny['ingress'] and not deny['egress'] and not deny['pod_selector'][0].get('match_labels')
        peer = policies['allow-cluster-dns']['egress'][0]['to']
        checks['dns-peer-and'] = len(peer) == 1 and peer[0]['namespace_selector'][0]['match_labels'] == {'kubernetes.io/metadata.name':'kube-system'} and peer[0]['pod_selector'][0]['match_labels'] == {'k8s-app':'kube-dns'}
        quota = only('kubernetes_resource_quota_v1')['spec'][0]['hard']
        checks['bounded-workloads'] = quota['services.loadbalancers'] == '0' and quota['services.nodeports'] == '0' and quota['pods'] == '20'
    elif suite == 'modules/pod-identity':
        trust = json.loads(only('aws_iam_role')['assume_role_policy'])['Statement'][0]
        checks['exact-workload-trust'] = trust['Principal'] == {'Service':'pods.eks.amazonaws.com'} and set(trust['Action']) == {'sts:AssumeRole','sts:TagSession'} and trust['Condition']['StringEquals'] == {'aws:RequestTag/eks-cluster-arn':'arn:aws:eks:us-west-2:111122223333:cluster/baseline-test','aws:RequestTag/kubernetes-namespace':'payments','aws:RequestTag/kubernetes-service-account':'report-reader'}
        statement = json.loads(only('aws_iam_role_policy')['policy'])['Statement']
        checks['get-object-prefix-only'] = statement == [{'Effect':'Allow','Action':['s3:GetObject'],'Resource':['arn:aws:s3:::example-reports/reports/daily/*']}]
    else:
        spec = only('kubernetes_network_policy_v1')['spec'][0]
        checks['dns-api-egress'] = {p['ip_block'][0]['cidr'] for p in spec['egress'][0]['to']} == {'10.20.0.0/16','172.20.0.1/32'} and spec['egress'][0]['ports'][0]['port'] == '443'
        checks['dns-port-only'] = {p['protocol']+'/'+p['port'] for p in spec['ingress'][0]['ports']} == {'UDP/53','TCP/53'}
        # Dependency edges are configuration, absent from test-plan JSON. Inspect HCL structurally.
        import hcl2
        conf = hcl2.loads((root/suite/'main.tf').read_text())
        addon = next(v['aws_eks_addon']['coredns'] for v in conf['resource'] if 'aws_eks_addon' in v)
        checks['dns-before-addon'] = addon.get('depends_on') in (['${kubernetes_network_policy_v1.coredns}'], [['${kubernetes_network_policy_v1.coredns}']])
    return checks


def run_suite(root, suite, positive):
    cmd = ['terraform', f'-chdir={root/suite}', 'test', '-json', '-verbose', '-no-color']
    env = dict(os.environ, TF_IN_AUTOMATION='true', TF_INPUT='false', AWS_EC2_METADATA_DISABLED='true')
    p = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=180)
    events = [json.loads(l) for l in p.stdout.splitlines() if l.startswith('{')]
    summary = next((e['test_summary'] for e in events if e.get('type')=='test_summary'), {})
    plan = next((e['test_plan'] for e in events if e.get('type')=='test_plan' and e.get('@testrun')==positive), None)
    if not plan:
        raise RuntimeError(p.stdout[-10000:] + p.stderr[-3000:])
    checks = contract(plan, suite, root)
    return p.returncode, summary, checks, p.stdout


MUTATIONS = [
    ('.','main.tf','endpoint_public_access                   = false','endpoint_public_access                   = true','private-api'),
    ('.','main.tf','["api", "audit", "authenticator", "controllerManager", "scheduler"]','["api", "authenticator", "controllerManager", "scheduler"]','all-control-plane-logs'),
    ('.','main.tf','enable_cluster_creator_admin_permissions = false','enable_cluster_creator_admin_permissions = true','one-explicit-admin'),
    ('.','main.tf','NETWORK_POLICY_ENFORCING_MODE = "strict"','NETWORK_POLICY_ENFORCING_MODE = "standard"','strict-network-policy'),
    ('.','main.tf','http_put_response_hop_limit = 1','http_put_response_hop_limit = 2','imdsv2-hop-one'),
    ('.','nodes.tf','AmazonEC2ContainerRegistryPullOnly','AmazonEC2ContainerRegistryReadOnly','bounded-node-policies'),
    ('modules/namespace','modules/namespace/main.tf','"pod-security.kubernetes.io/enforce"         = "restricted"','"pod-security.kubernetes.io/enforce"         = "baseline"','restricted-psa'),
    ('modules/namespace','modules/namespace/main.tf','automount_service_account_token = false','automount_service_account_token = true','no-api-token'),
    ('modules/namespace','modules/namespace/main.tf','policy_types = ["Ingress", "Egress"]','policy_types = ["Ingress"]','bidirectional-deny'),
    ('modules/namespace','modules/namespace/main.tf','"k8s-app" = "kube-dns"','"k8s-app" = "other"','dns-peer-and'),
    ('modules/pod-identity','modules/pod-identity/main.tf','["s3:GetObject"]','["s3:*"]','get-object-prefix-only'),
    ('modules/pod-identity','modules/pod-identity/main.tf','"aws:RequestTag/kubernetes-service-account" = var.service_account','"aws:RequestTag/kubernetes-service-account" = "other"','exact-workload-trust'),
    ('modules/cluster-services','modules/cluster-services/main.tf','depends_on                  = [kubernetes_network_policy_v1.coredns]','depends_on                  = []','dns-before-addon'),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--mutations', action='store_true')
    ap.add_argument('--output', default='artifacts/regressions.json')
    args = ap.parse_args()
    report = {'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'kind':'mock-provider plans; no AWS calls or deployment', 'terraform_version':subprocess.check_output(['terraform','version','-json'],text=True).strip(), 'suites':{}, 'mutations':[], 'source_sha256':source_manifest()}
    out = ROOT/args.output
    out.parent.mkdir(parents=True,exist_ok=True)
    for suite,positive in SUITES.items():
        code,summary,checks,raw = run_suite(ROOT,suite,positive)
        (ROOT/'artifacts').mkdir(exist_ok=True)
        (ROOT/'artifacts'/('tests-'+suite.replace('/','-').replace('.','root')+'.jsonl')).write_text(raw)
        assert code == 0 and summary.get('status')=='pass' and all(checks.values()), (suite,summary,checks)
        report['suites'][suite] = {'native':summary, 'contracts':checks}
        print(f'{suite}: {summary["passed"]} native runs, {len(checks)} composed-resource contracts passed', flush=True)
    if args.mutations:
        for suite,file,old,new,label in MUTATIONS:
            with tempfile.TemporaryDirectory(prefix='eks-baseline-mutation-') as tmp:
                clone=Path(tmp)/'module'
                shutil.copytree(ROOT,clone,ignore=shutil.ignore_patterns('.terraform','.git','artifacts','__pycache__'))
                for folder in ['.',*list(SUITES)[1:]]:
                    (clone/folder/'.terraform').symlink_to((ROOT/folder/'.terraform').resolve(),target_is_directory=True)
                target=clone/file
                content=target.read_text()
                assert content.count(old)==1, ('mutation anchor',label,content.count(old))
                target.write_text(content.replace(old,new))
                # Run only the positive fixture against the mutated implementation.
                for test in (clone/suite/'tests').glob('*.tftest.hcl'):
                    s=test.read_text(); i=s.find('run "reject_'); test.write_text(s[:i] if i>=0 else s)
                _,summary,checks,_=run_suite(clone,suite,SUITES[suite])
                assert checks.get(label) is False, ('mutation survived',label,summary,checks)
                report['mutations'].append({'control':label,'rejected':True})
                print(f'MUTATION REJECTED: {label}',flush=True)
    out.write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS: {sum(x["native"]["passed"] for x in report["suites"].values())} native runs; {len(report["mutations"])} rejected source mutations')


if __name__=='__main__':
    main()

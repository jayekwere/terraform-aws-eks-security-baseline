#!/usr/bin/env python3
"""Apply the actual namespace module to an explicitly selected disposable kind cluster.

Only Kubernetes objects inside a new namespace are created. Pod requests use
server-side dry-run; images are not pulled and workloads are not started.
"""
import argparse
from copy import deepcopy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--kubeconfig',required=True)
    ap.add_argument('--context',default='kind-eks-baseline-admission')
    ap.add_argument('--output',default='artifacts/admission.json')
    a=ap.parse_args()
    if a.context != 'kind-eks-baseline-admission':
        raise SystemExit('Refusing any context except kind-eks-baseline-admission')
    kubeconfig=str(Path(a.kubeconfig).resolve())
    kubectl=['kubectl','--kubeconfig',kubeconfig,'--context',a.context]
    namespace='baseline-admission-check'
    probe=subprocess.run([*kubectl,'get','namespace',namespace],capture_output=True,text=True)
    if probe.returncode==0 or 'NotFound' not in probe.stderr:
        raise SystemExit('Namespace must be absent and the disposable cluster reachable')
    report={'recorded_at_utc':datetime.now(timezone.utc).isoformat(),'kind':'real Kubernetes API dry-run admission; no EKS/CNI/IAM runtime validation','server':json.loads(subprocess.check_output([*kubectl,'version','-o','json'],text=True))['serverVersion'],'cases':[]}
    with tempfile.TemporaryDirectory(prefix='eks-baseline-admission-') as tmp:
        p=Path(tmp)
        config={
          'terraform':{'required_version':'>= 1.15.0, < 2.0.0','required_providers':{'kubernetes':{'source':'hashicorp/kubernetes','version':'>= 2.38.0, < 3.0.0'}}},
          'provider':{'kubernetes':{'config_path':kubeconfig,'config_context':a.context}},
          'module':{'namespace':{'source':str(ROOT/'modules/namespace'),'name':namespace,'psa_version':'v1.35'}}}
        (p/'main.tf.json').write_text(json.dumps(config))
        shutil.copyfile(ROOT/'modules/namespace/.terraform.lock.hcl',p/'.terraform.lock.hcl')
        cmd=['terraform',f'-chdir={p}']
        env=dict(os.environ,TF_IN_AUTOMATION='true',TF_INPUT='false')
        subprocess.run([*cmd,'init','-backend=false','-input=false','-lockfile=readonly','-no-color'],check=True,env=env,stdout=subprocess.DEVNULL)
        try:
            subprocess.run([*cmd,'apply','-auto-approve','-input=false','-no-color'],check=True,env=env,stdout=subprocess.DEVNULL)
            pod=json.loads((ROOT/'fixtures/restricted-pod.json').read_text())
            pod['metadata']['namespace']=namespace
            def check(name,obj,allowed,reason):
                result=subprocess.run([*kubectl,'create','--dry-run=server','-f','-','-o','json'],input=json.dumps(obj),capture_output=True,text=True)
                ok=result.returncode==0
                assert ok==allowed and (allowed or reason in result.stderr),(name,result.stdout,result.stderr)
                report['cases'].append({'case':name,'allowed':ok,'expected_allowed':allowed,'reason':reason,'response':result.stderr.strip() if not ok else 'server dry-run accepted'})
                print(f'{name}: '+('allowed' if ok else 'rejected'))
            check('restricted-pod',pod,True,'restricted:v1.35')
            for name,modify in [
                ('privileged',lambda v:v['spec']['containers'][0]['securityContext'].update(privileged=True,allowPrivilegeEscalation=True)),
                ('host-network',lambda v:v['spec'].update(hostNetwork=True)),
                ('root-user',lambda v:v['spec']['securityContext'].update(runAsUser=0)),
                ('privilege-escalation',lambda v:v['spec']['containers'][0]['securityContext'].update(allowPrivilegeEscalation=True)),
                ('added-capability',lambda v:v['spec']['containers'][0]['securityContext']['capabilities'].update(add=['NET_ADMIN'])),
                ('unconfined-seccomp',lambda v:v['spec']['securityContext'].update(seccompProfile={'type':'Unconfined'})),
                ('host-path',lambda v:v['spec'].update(volumes=[{'name':'host','hostPath':{'path':'/'}}])),
            ]:
                obj=deepcopy(pod);modify(obj);check(name,obj,False,'violates PodSecurity')
            for kind,extra in [('NodePort',{}),('LoadBalancer',{})]:
                svc={'apiVersion':'v1','kind':'Service','metadata':{'name':'blocked-service','namespace':namespace},'spec':{'type':kind,'ports':[{'port':80,'targetPort':8080}]}}
                check(kind,svc,False,'exceeded quota')
            # Explicitly prove the PSA limits: these are allowed, so README must not claim they are enforced.
            obj=deepcopy(pod);obj['spec']['containers'][0]['securityContext']['readOnlyRootFilesystem']=False
            check('psa-does-not-require-readonly-root',obj,True,'outside PSA')
            obj=deepcopy(pod);obj['spec']['automountServiceAccountToken']=True
            check('psa-does-not-forbid-explicit-api-token',obj,True,'outside PSA')
        finally:
            cleanup=subprocess.run([*cmd,'destroy','-auto-approve','-input=false','-no-color'],env=env,capture_output=True,text=True)
            report['terraform_destroy_exit_code']=cleanup.returncode
            if cleanup.returncode:
                print(cleanup.stderr)
                raise RuntimeError('Namespace cleanup failed')
    out=ROOT/a.output;out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS: {len(report["cases"])} admission requests; Terraform namespace removed')


if __name__=='__main__': main()

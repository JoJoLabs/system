import yaml
import json

crdjson = {}
with open('calico-crds.yaml') as crd_file:
  crds = yaml.safe_load_all(crd_file)
  for crd in crds:
    crdjson[crd['metadata']['name']] = crd

with open('calico-crds.json', 'w') as out:
  out.write(json.dumps(crdjson))
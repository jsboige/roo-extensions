import json, sys

data = json.load(sys.stdin)
items = data['data']['user']['projectV2']['items']['nodes']
for item in items:
    c = item.get('content')
    if not c or c.get('state') != 'OPEN':
        continue
    fields = {}
    for fv in item['fieldValues']['nodes']:
        if fv.get('name') and fv.get('field'):
            fields[fv['field']['name']] = fv['name']
    machine = fields.get('Machine', '-')
    agent = fields.get('Agent', '-')
    status = fields.get('Status', '-')
    num = c['number']
    title = c['title'][:60]
    print(f"#{num} | {status} | {machine} | {agent} | {title}")

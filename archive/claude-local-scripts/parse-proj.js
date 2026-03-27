const d = JSON.parse(require("fs").readFileSync("d:/dev/roo-extensions/.claude/local/proj67.json", "utf8"));
for (const i of d.data.user.projectV2.items.nodes) {
  const c = i.content;
  if (c === null || c === undefined || c.state !== "OPEN") continue;
  const f = {};
  for (const v of i.fieldValues.nodes) {
    if (v.field && v.field.name) f[v.field.name] = v.name;
  }
  console.log("#" + c.number + " " + c.title.substring(0, 55) + " | " + JSON.stringify(f));
}

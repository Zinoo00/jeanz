import { readFileSync } from "node:fs";
import { parseSync } from "oxc-parser";

const WHY = {
  any: "`any`",
  cast: "a cast",
  nonNull: "a non-null assertion",
  comment: "a comment that switches the type-check off",
  functionType: "the `Function` type",
  definite: "a definite-assignment assertion",
  declared: "a `declare` of a value",
  untyped: "a call that returns `any`, outside a value annotated `unknown`",
};
const BY_TYPE = { TSAnyKeyword: WHY.any, TSAsExpression: WHY.cast, TSTypeAssertion: WHY.cast, TSNonNullExpression: WHY.nonNull };
const RETURNS_ANY = new Set(["JSON.parse", "Reflect.get", "Reflect.apply", "Reflect.construct"]);

function isConstAssertion(node) {
  return node.type === "TSAsExpression" && node.typeAnnotation.type === "TSTypeReference" && node.typeAnnotation.typeName.name === "const";
}

function returnsAny(call) {
  const callee = call.callee;
  if (callee.type !== "MemberExpression" || callee.computed) return false;
  if (callee.property.name === "json" && call.arguments.length === 0) return true;
  return callee.object.type === "Identifier" && RETURNS_ANY.has(`${callee.object.name}.${callee.property.name}`);
}

function annotatedUnknown(parents) {
  const holder = parents.findLast((parent) => parent.type !== "AwaitExpression");
  return holder?.type === "VariableDeclarator" && holder.id.typeAnnotation?.typeAnnotation.type === "TSUnknownKeyword";
}

function loose(node, parents) {
  if (BY_TYPE[node.type]) return isConstAssertion(node) ? null : BY_TYPE[node.type];
  if (node.type === "TSTypeReference" && node.typeName.name === "Function") return WHY.functionType;
  if ((node.type === "VariableDeclarator" || node.type === "PropertyDefinition") && node.definite) return WHY.definite;
  if ((node.type === "VariableDeclaration" || node.type === "TSDeclareFunction" || node.type === "ClassDeclaration") && node.declare) return WHY.declared;
  if (node.type === "CallExpression" && returnsAny(node) && !annotatedUnknown(parents)) return WHY.untyped;
  return null;
}

let found = false;
for (const path of process.argv.slice(2)) {
  const source = readFileSync(path, "utf8");
  const { program, comments } = parseSync(path, source);
  const report = (offset, what) => {
    found = true;
    console.log(`    ${path}:${source.slice(0, offset).split("\n").length}: ${what}`);
  };
  for (const comment of comments) {
    if (/@ts-(nocheck|ignore|expect-error)/.test(comment.value)) report(comment.start, WHY.comment);
  }
  const walk = (node, parents) => {
    if (Array.isArray(node)) return node.forEach((child) => walk(child, parents));
    if (node === null || typeof node !== "object") return;
    if (typeof node.type !== "string") return Object.values(node).forEach((child) => walk(child, parents));
    const what = loose(node, parents);
    if (what) report(node.start, what);
    Object.values(node).forEach((child) => walk(child, [...parents, node]));
  };
  walk(program, []);
}
process.exit(found ? 1 : 0);

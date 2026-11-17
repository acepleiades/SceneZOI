"""Validate registered body and attachment variants and role appearance defaults."""
import re

IDENTIFIER = re.compile(r"[a-z][a-z0-9_.-]{0,95}")
ASSET = re.compile(r"/[A-Za-z0-9_/]+[.][A-Za-z0-9_]+")


def fields(value, allowed, required=()):
    if not isinstance(value, dict) or set(value) - set(allowed) or set(required) - set(value):
        raise ValueError("Invalid appearance variant fields")


def identifier(value):
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise ValueError("Invalid appearance variant identifier")


def name(value):
    if (not isinstance(value, str) or not value.strip() or len(value.encode("utf-8")) > 160
            or any(ord(char) < 32 for char in value)):
        raise ValueError("Invalid appearance variant name")


def asset(value):
    if not isinstance(value, str) or len(value) > 512 or not ASSET.fullmatch(value):
        raise ValueError("Invalid appearance variant asset path")


def identity(value, owner):
    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        raise ValueError("Unsupported appearance variant schema")
    identifier(value["id"])
    if owner is not None:
        identifier(owner)
        if len(value["id"]) <= len(owner) + 1 or not value["id"].startswith(owner + "."):
            raise ValueError("Variant ID must use its pack namespace")
    if "label" in value:
        name(value["label"])


def traits(value, required):
    if required or "body" in value:
        if value.get("body") not in ("male", "female"):
            raise ValueError("Invalid appearance variant body")
    if "body_age" in value:
        name(value["body_age"])
    if "growth_steps" in value:
        steps = value["growth_steps"]
        if not isinstance(steps, list) or not 1 <= len(steps) <= 16:
            raise ValueError("Invalid appearance variant life stages")
        for step in steps:
            name(step)
        if len(set(steps)) != len(steps):
            raise ValueError("Duplicate appearance variant life stage")


def body_variant(value, owner=None):
    fields(value, ["schema_version", "id", "label", "body", "mesh", "body_age", "growth_steps"],
           ["schema_version", "id", "body", "mesh"])
    identity(value, owner)
    traits(value, True)
    asset(value["mesh"])


def attachment_variant(value, owner=None):
    fields(value, ["schema_version", "id", "label", "body", "body_age", "growth_steps", "attachment", "node_animations"],
           ["schema_version", "id", "attachment"])
    identity(value, owner)
    traits(value, False)
    attachment = value["attachment"]
    fields(attachment, ["mesh", "component", "socket", "reference_bone", "body_profile", "material_profile", "retain_for_session"],
           ["mesh", "socket", "reference_bone"])
    asset(attachment["mesh"])
    name(attachment["socket"])
    name(attachment["reference_bone"])
    if "component" in attachment and attachment["component"] not in ("body", "head"):
        raise ValueError("Invalid attachment variant component")
    if "body_profile" in attachment:
        identifier(attachment["body_profile"])
        if attachment.get("component") == "head":
            raise ValueError("A body-region variant requires the body component")
    if "material_profile" in attachment:
        identifier(attachment["material_profile"])
        if "body_profile" not in attachment:
            raise ValueError("An attachment material profile requires a body profile")
    if "retain_for_session" in attachment and type(attachment["retain_for_session"]) is not bool:
        raise ValueError("Invalid attachment variant retention")
    animations = value.get("node_animations", {})
    if not isinstance(animations, dict) or len(animations) > 512:
        raise ValueError("Invalid attachment variant scene animation map")
    for scene_id, path in animations.items():
        identifier(scene_id)
        asset(path)


def selection(value):
    fields(value, ["body_variant", "attachment_variants"])
    if "body_variant" in value and value["body_variant"] is not False:
        identifier(value["body_variant"])
    if "attachment_variants" in value:
        slots = value["attachment_variants"]
        if not isinstance(slots, dict) or len(slots) > 16:
            raise ValueError("Invalid attachment variant slots")
        for slot, variant_id in slots.items():
            identifier(slot)
            if variant_id is not False:
                identifier(variant_id)


def scene(value, roles):
    if not isinstance(value, dict):
        raise ValueError("Expected appearance selections by role")
    for role, spec in value.items():
        if role not in roles:
            raise ValueError("Unbound appearance selection role")
        selection(spec)


def validate_documents(documents):
    definitions = {}
    validators = {"body_variant": body_variant, "attachment_variant": attachment_variant}
    for owner, kind, source, data in documents:
        if kind not in validators:
            continue
        validators[kind](data, owner)
        identity_key = (kind, data["id"])
        if identity_key in definitions and definitions[identity_key] != data:
            raise ValueError("Conflicting appearance variant " + data["id"] + " in " + str(source))
        definitions[identity_key] = data

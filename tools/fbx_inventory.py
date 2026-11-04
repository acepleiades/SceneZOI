"""Read binary FBX timing and skeleton metadata without loading an authoring app."""
import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

TICKS = 46186158000
RATES = {1: 120, 2: 100, 3: 60, 4: 50, 5: 48, 6: 30, 7: 30,
         8: 30000 / 1001, 9: 30000 / 1001, 10: 25, 11: 24,
         12: 1000, 13: 24, 15: 96, 16: 72, 17: 60000 / 1001}


def parse(path):
    data = path.read_bytes()
    assert data[:23] == b'Kaydara FBX Binary  \x00\x1a\x00', 'Not a binary FBX'
    version = struct.unpack_from('<I', data, 23)[0]
    header = '<QQQB' if version >= 7500 else '<IIIB'
    size = struct.calcsize(header)

    def node(offset):
        end, count, _, name_len = struct.unpack_from(header, data, offset)
        if end == 0:
            return None, offset + size
        offset += size
        name = data[offset:offset + name_len].decode()
        offset += name_len
        props = []
        for _ in range(count):
            kind = chr(data[offset])
            offset += 1
            scalar = {'Y': 'h', 'C': '?', 'I': 'i', 'F': 'f', 'D': 'd', 'L': 'q'}
            arrays = {'f': 'f', 'd': 'd', 'l': 'q', 'i': 'i', 'b': '?', 'c': 'b'}
            if kind in scalar:
                fmt = '<' + scalar[kind]
                value = struct.unpack_from(fmt, data, offset)[0]
                offset += struct.calcsize(fmt)
            elif kind in ('S', 'R'):
                length = struct.unpack_from('<I', data, offset)[0]
                offset += 4
                value = data[offset:offset + length]
                offset += length
                if kind == 'S':
                    value = value.decode('utf-8', errors='replace')
            elif kind in arrays:
                length, encoding, byte_len = struct.unpack_from('<III', data, offset)
                offset += 12
                # Only time arrays are needed for an inventory; avoid decoding transforms.
                if name == 'KeyTime':
                    raw = data[offset:offset + byte_len]
                    if encoding == 1:
                        raw = zlib.decompress(raw)
                    value = list(struct.unpack('<' + str(length) + arrays[kind], raw))
                else:
                    value = {'array_length': length}
                offset += byte_len
            else:
                raise ValueError(f'Unknown property {kind} at {offset}')
            props.append(value)
        children = []
        while offset < end:
            child, offset = node(offset)
            if child is None:
                break
            children.append(child)
        return {'name': name, 'props': props, 'children': children}, end

    nodes, offset = [], 27
    while True:
        entry, offset = node(offset)
        if entry is None:
            break
        nodes.append(entry)
    return version, nodes


def descendants(nodes, name):
    for n in nodes:
        if n['name'] == name:
            yield n
        yield from descendants(n['children'], name)


def inventory(path):
    version, nodes = parse(path)
    globals_node = next(descendants(nodes, 'GlobalSettings'))
    properties = {p['props'][0]: p['props'][4:] for p in descendants(globals_node['children'], 'P')}
    mode = properties['TimeMode'][0]
    rate = properties.get('CustomFrameRate', [0])[0] if mode == 14 else RATES[mode]
    stacks = []
    for stack in descendants(nodes, 'AnimationStack'):
        p = {x['props'][0]: x['props'][4:] for x in descendants(stack['children'], 'P')}
        start, end = p.get('LocalStart', [0])[0], p.get('LocalStop', [0])[0]
        stacks.append({'name': stack['props'][1].split('\x00')[0],
                       'start_ticks': start, 'end_ticks': end,
                       'start_frame': round(start / TICKS * rate, 8),
                       'end_frame': round(end / TICKS * rate, 8),
                       'duration_seconds': (end - start) / TICKS,
                       'inclusive_samples': round((end - start) / TICKS * rate) + 1})
    models = [n['props'][1].split('\x00')[0] for n in descendants(nodes, 'Model')
              if n['props'][2] == 'LimbNode']
    times = [n['props'][0] for n in descendants(nodes, 'KeyTime')]
    return {'filename': path.name, 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'fbx_version': version, 'time_mode': mode, 'fps': rate,
            'takes': stacks, 'limb_node_count': len(models), 'limb_nodes': models,
            'animation_curve_count': len(times),
            'key_sample_counts': sorted(set(map(len, times))),
            'key_start_frame': round(min(min(t) for t in times) / TICKS * rate, 8),
            'key_end_frame': round(max(max(t) for t in times) / TICKS * rate, 8)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = [inventory(path) for path in sorted(args.directory.glob('*.fbx'))]
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    for item in result:
        print(item['filename'], item['fps'], item['takes'],
              'bones=', item['limb_node_count'], 'keys=', item['key_sample_counts'])

import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Divider,
  Dropdown,
  Input,
  LabeledList,
  NumberInput,
  Section,
  Stack,
} from '../components';
import { VirtualList } from '../components/VirtualList';
import { Window } from '../layouts';

const DIRECTIONS = [
  { value: 1, label: 'North' },
  { value: 2, label: 'South' },
  { value: 4, label: 'East' },
  { value: 8, label: 'West' },
];

const WHERE_OPTIONS = ['On Floor', 'In Marked Object'];

type AdminSpawnerData = {
  types: string[];
};

export const AdminSpawner = () => {
  const { act, data } = useBackend<AdminSpawnerData>();
  const { types } = data;

  const [filter, setFilter] = useState('');
  const [selected, setSelected] = useState('');
  const [offsetX, setOffsetX] = useState(0);
  const [offsetY, setOffsetY] = useState(0);
  const [offsetZ, setOffsetZ] = useState(0);
  const [offsetMode, setOffsetMode] = useState<'relative' | 'absolute'>(
    'relative',
  );
  const [count, setCount] = useState(1);
  const [direction, setDirection] = useState(2);
  const [customName, setCustomName] = useState('');
  const [where, setWhere] = useState('On Floor');

  const lowerFilter = filter.toLowerCase();
  const filtered = filter
    ? types.filter((t) => t.toLowerCase().includes(lowerFilter))
    : types;

  const dirLabel =
    DIRECTIONS.find((d) => d.value === direction)?.label ?? 'South';

  const handleSpawn = () => {
    if (!selected) return;
    act('spawn', {
      type: selected,
      offset_x: offsetX,
      offset_y: offsetY,
      offset_z: offsetZ,
      offset_type: offsetMode,
      count,
      dir: direction,
      name: customName || null,
      where: where === 'On Floor' ? 'onfloor' : 'inmarked',
    });
  };

  return (
    <Window title="Admin Spawner" width={520} height={570} theme="crtblue">
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section title="Mob Type">
              <Input
                fluid
                autoFocus
                placeholder="Search mob types…"
                value={filter}
                onInput={(e, value) => {
                  setFilter(value);
                  setSelected('');
                }}
                mb={1}
              />
              <Box
                style={{
                  height: '220px',
                  border: '1px solid var(--color-border, #8ac8ff)',
                  overflowY: 'auto',
                  fontFamily: 'monospace',
                  fontSize: '0.85em',
                }}
              >
                <VirtualList>
                  {filtered.map((type) => (
                    <Box
                      key={type}
                      p={0.5}
                      style={{
                        cursor: 'pointer',
                        background:
                          selected === type
                            ? 'rgba(138,200,255,0.2)'
                            : 'transparent',
                        borderLeft:
                          selected === type
                            ? '2px solid #8ac8ff'
                            : '2px solid transparent',
                      }}
                      onClick={() => setSelected(type)}
                    >
                      {type}
                    </Box>
                  ))}
                </VirtualList>
              </Box>
              {selected && (
                <Box mt={0.5} color="label" fontSize="0.85em" truncate>
                  Selected: {selected}
                </Box>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Spawn Options">
              <LabeledList>
                <LabeledList.Item label="Offset">
                  <Stack align="center">
                    <Stack.Item>
                      <NumberInput
                        value={offsetX}
                        minValue={-255}
                        maxValue={255}
                        width="4em"
                        onChange={(val) => setOffsetX(val)}
                        unit="X"
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={offsetY}
                        minValue={-255}
                        maxValue={255}
                        width="4em"
                        onChange={(val) => setOffsetY(val)}
                        unit="Y"
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={offsetZ}
                        minValue={-255}
                        maxValue={255}
                        width="4em"
                        onChange={(val) => setOffsetZ(val)}
                        unit="Z"
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        checked={offsetMode === 'absolute'}
                        onClick={() =>
                          setOffsetMode(
                            offsetMode === 'absolute' ? 'relative' : 'absolute',
                          )
                        }
                      >
                        Absolute
                      </Button.Checkbox>
                    </Stack.Item>
                  </Stack>
                </LabeledList.Item>
                <LabeledList.Item label="Count">
                  <NumberInput
                    value={count}
                    minValue={1}
                    maxValue={50}
                    width="4em"
                    onChange={(val) => setCount(val)}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Direction">
                  <Dropdown
                    selected={dirLabel}
                    options={DIRECTIONS.map((d) => d.label)}
                    onSelected={(label) => {
                      const dir = DIRECTIONS.find((d) => d.label === label);
                      if (dir) setDirection(dir.value);
                    }}
                    width="8em"
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Custom Name">
                  <Input
                    fluid
                    placeholder="(optional)"
                    value={customName}
                    onInput={(e, value) => setCustomName(value)}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Place">
                  <Dropdown
                    selected={where}
                    options={WHERE_OPTIONS}
                    onSelected={(val) => setWhere(val)}
                    width="12em"
                  />
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Stack justify="flex-end">
              <Stack.Item>
                <Button
                  icon="plus-circle"
                  color="good"
                  disabled={!selected}
                  onClick={handleSpawn}
                  tooltip={!selected ? 'Select a mob type first' : undefined}
                >
                  Spawn
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

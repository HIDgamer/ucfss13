import { useBackend } from '../backend';
import { Box, Button, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

export const AdminAIDifficulty = () => {
  const { act, data } = useBackend();
  const {
    ai_xeno_count = 0,
    ai_xeno_max = 0,
    ai_flee_multiplier = 1,
    ai_distance_multiplier = 1,
    ai_castes = [],
    ai_caste_caps = {},
    ai_caste_counts = {},
    difficulty_multiplier = 1,
  } = data;

  return (
    <Window title="AI Difficulty" theme="crtblue" width={480} height={640}>
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Difficulty">
              <Stack>
                <Stack.Item>
                  <NumberInput
                    value={difficulty_multiplier}
                    minValue={0.25}
                    maxValue={4}
                    step={0.25}
                    format={(v) => `${v}x`}
                    width="5rem"
                    onChange={(v) => act('set_difficulty', { value: v })}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Box
                    style={{
                      fontSize: '0.75rem',
                      color: 'rgba(255,255,255,0.5)',
                      paddingTop: '4px',
                    }}
                  >
                    Merged with the behavior presets below - moving one
                    updates the other. 1x = default.
                  </Box>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="AI Xenomorph Population">
              <Stack>
                <Stack.Item>
                  <Box style={{ fontSize: '0.85rem' }}>
                    {ai_xeno_count} / {ai_xeno_max} active
                  </Box>
                </Stack.Item>
                <Stack.Item grow />
                <Stack.Item>
                  <NumberInput
                    value={ai_xeno_max}
                    minValue={0}
                    maxValue={200}
                    step={5}
                    width="5rem"
                    onChange={(v) => act('set_ai_cap', { value: v })}
                  />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="AI Behavior">
              <Stack vertical>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Button
                        fluid
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'passive' })
                        }
                      >
                        Passive
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'balanced' })
                        }
                      >
                        Balanced
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'aggressive' })
                        }
                      >
                        Aggressive
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        color="bad"
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'ruthless' })
                        }
                      >
                        Ruthless
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>Flee threshold</Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        Below 1x fights longer before disengaging.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={ai_flee_multiplier}
                        minValue={0.1}
                        maxValue={3}
                        step={0.1}
                        format={(v) => `${v}x`}
                        width="5rem"
                        onChange={(v) =>
                          act('set_flee_multiplier', { value: v })
                        }
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>
                        Awareness/leash range
                      </Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        Scales target-scan radius and how far a xeno chases from
                        its anchor.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={ai_distance_multiplier}
                        minValue={0.25}
                        maxValue={3}
                        step={0.1}
                        format={(v) => `${v}x`}
                        width="5rem"
                        onChange={(v) =>
                          act('set_distance_multiplier', { value: v })
                        }
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Section title="Per-Caste Population Caps" fill scrollable>
              <Stack vertical>
                {ai_castes.map((caste) => (
                  <Stack.Item key={caste}>
                    <Stack>
                      <Stack.Item grow>
                        <Box style={{ fontSize: '0.8rem' }}>{caste}</Box>
                        <Box
                          style={{
                            fontSize: '0.7rem',
                            color: 'rgba(255,255,255,0.5)',
                          }}
                        >
                          {ai_caste_counts[caste] || 0} active
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <NumberInput
                          value={ai_caste_caps[caste] || 0}
                          minValue={0}
                          maxValue={100}
                          step={1}
                          format={(v) => (v <= 0 ? 'no cap' : `${v}`)}
                          width="5.5rem"
                          onChange={(v) =>
                            act('set_caste_cap', { caste: caste, value: v })
                          }
                        />
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

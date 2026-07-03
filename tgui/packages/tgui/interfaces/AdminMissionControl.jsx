import { useBackend } from '../backend';
import { Box, Button, Icon, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

export const AdminMissionControl = () => {
  const { act, data } = useBackend();
  const {
    ai_xeno_count = 0,
    ai_xeno_max = 0,
    mode_active = false,
    dynamic_missions_enabled = false,
    controller_active = false,
    difficulty_multiplier = 1,
    completed_count = 0,
    failed_count = 0,
    objective_active = false,
    objective_name = '',
    objective_description = '',
    objective_elapsed = 0,
    objective_time_limit = 0,
  } = data;

  return (
    <Window title="Mission Control" theme="crtblue" width={480} height={520}>
      <Window.Content>
        <Stack vertical fill>
          {!mode_active && (
            <Stack.Item>
              <Box
                style={{
                  padding: '8px',
                  color: 'rgba(255,255,255,0.5)',
                  fontStyle: 'italic',
                }}
              >
                <Icon name="triangle-exclamation" style={{ marginRight: '6px' }} />
                Current gamemode isn&apos;t Distress Signal - nothing to control.
              </Box>
            </Stack.Item>
          )}

          {mode_active && (
            <Stack.Item>
              <Section title="Dynamic Mission System">
                <Stack vertical>
                  <Stack.Item>
                    <Button
                      fluid
                      icon={dynamic_missions_enabled ? 'toggle-on' : 'toggle-off'}
                      color={dynamic_missions_enabled ? 'green' : 'red'}
                      onClick={() => act('toggle_dynamic_missions')}
                    >
                      {dynamic_missions_enabled ? 'Enabled' : 'Disabled'}
                    </Button>
                  </Stack.Item>
                  {controller_active && (
                    <Stack.Item>
                      <Box style={{ fontSize: '0.82rem', color: '#8cf' }}>
                        {completed_count} objective(s) completed, {failed_count}{' '}
                        failed this round.
                      </Box>
                    </Stack.Item>
                  )}
                </Stack>
              </Section>
            </Stack.Item>
          )}

          {controller_active && (
            <Stack.Item>
              <Section title="Current Objective">
                {objective_active ? (
                  <Stack vertical>
                    <Stack.Item>
                      <Box style={{ fontWeight: 'bold', color: '#8cf' }}>
                        {objective_name}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Box
                        style={{
                          fontSize: '0.8rem',
                          color: 'rgba(255,255,255,0.7)',
                        }}
                      >
                        {objective_description}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Box style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.5)' }}>
                        Elapsed: {objective_elapsed}s
                        {objective_time_limit
                          ? ` / ${objective_time_limit}s limit`
                          : ' (no time limit)'}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Stack>
                        <Stack.Item grow>
                          <Button
                            fluid
                            icon="check"
                            color="green"
                            onClick={() => act('force_complete')}
                          >
                            Force Complete
                          </Button>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Button
                            fluid
                            icon="xmark"
                            color="red"
                            onClick={() => act('force_fail')}
                          >
                            Force Fail
                          </Button>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                  </Stack>
                ) : (
                  <Box
                    style={{
                      color: 'rgba(255,255,255,0.3)',
                      fontStyle: 'italic',
                    }}
                  >
                    No active objective right now.
                  </Box>
                )}
              </Section>
            </Stack.Item>
          )}

          {controller_active && (
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
                    <Box style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.5)', paddingTop: '4px' }}>
                      Scales objective time limits (and wave size once
                      generalized defense objectives land). 1x = default.
                    </Box>
                  </Stack.Item>
                </Stack>
              </Section>
            </Stack.Item>
          )}

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
        </Stack>
      </Window.Content>
    </Window>
  );
};

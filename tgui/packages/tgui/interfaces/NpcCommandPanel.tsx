import { type BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { Box, Button, Section, Stack, Tabs } from '../components';
import { Window } from '../layouts';
import { HumanCommandSide } from './NpcCommandConsole';
import { XenoCommandSide } from './XenoCommandConsole';

type Hive = {
  name: string;
  number: string;
};

type PanelData = {
  panel_mode: 'humans' | 'xenos';
  panel_humans: BooleanLike;
  panel_xenos: BooleanLike;
  needs_hive?: BooleanLike;
  available_hives?: Hive[];
};

/**
 * One window for everything that is run by an AI: the AI humans and the
 * hive's AI xenos, switched at the top when the user may have both.
 */
export const NpcCommandPanel = () => {
  const { act, data } = useBackend<PanelData>();
  const { panel_mode, panel_humans, panel_xenos, needs_hive } = data;
  const xenos = panel_mode === 'xenos';

  return (
    <Window title="NPC Command Panel" theme="admin" width={1040} height={820}>
      <Window.Content scrollable>
        <Stack vertical>
          {!!panel_humans && !!panel_xenos && (
            <Stack.Item>
              <Tabs>
                <Tabs.Tab
                  selected={!xenos}
                  onClick={() => act('set_panel_mode', { mode: 'humans' })}
                >
                  Humans
                </Tabs.Tab>
                <Tabs.Tab
                  selected={xenos}
                  onClick={() => act('set_panel_mode', { mode: 'xenos' })}
                >
                  Xenos
                </Tabs.Tab>
              </Tabs>
            </Stack.Item>
          )}
          <Stack.Item>
            {!xenos && <HumanCommandSide />}
            {xenos && !needs_hive && <XenoCommandSide />}
            {xenos && !!needs_hive && <HivePicker />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const HivePicker = () => {
  const { act, data } = useBackend<PanelData>();
  const { available_hives = [] } = data;

  return (
    <Section title="Which hive do you want to command?">
      {available_hives.length === 0 && (
        <Box color="grey">There are no hives.</Box>
      )}
      {available_hives.map((hive) => (
        <Button
          key={hive.number}
          mr={1}
          onClick={() => act('pick_hive', { hive: hive.number })}
        >
          {hive.name}
        </Button>
      ))}
    </Section>
  );
};

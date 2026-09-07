import { capitalize } from 'common/string';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Icon,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';
import { PrintProgress } from './common/PrintProgress';

type Data = {
  worldtime: number;
  loadedType: 'paper' | 'photo' | 'bundle' | null;
  loadedName: string | null;
  toner: number;
  maxToner: number;
  copies: number;
  maxcopies: number;
  printingActive: boolean;
  copiesCompleted: number;
  copiesTotal: number;
  currentCopyStartedAt: number;
  currentCopyEndsAt: number;
};

const documentIcons: Record<string, string> = {
  paper: 'file-lines',
  photo: 'image',
  bundle: 'folder',
};

export const Photocopier = () => {
  const { act, data } = useBackend<Data>();
  const {
    worldtime,
    loadedType,
    loadedName,
    toner,
    maxToner,
    copies,
    maxcopies,
    printingActive,
    copiesCompleted,
    copiesTotal,
    currentCopyStartedAt,
    currentCopyEndsAt,
  } = data;

  return (
    <Window theme="weyland" width={380} height={330}>
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Section
              title="Loaded Document"
              buttons={
                <Button.Confirm
                  icon="eject"
                  disabled={!loadedType}
                  onClick={() => act('remove_document')}
                >
                  Remove
                </Button.Confirm>
              }
            >
              {loadedType ? (
                <Box>
                  <Icon name={documentIcons[loadedType]} mr={1} />
                  {loadedName} ({capitalize(loadedType)})
                </Box>
              ) : (
                <Box color="label" fontStyle="italic">
                  No document loaded — insert paper, a photo, or a bundle.
                </Box>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Toner">
              <ProgressBar
                value={toner / maxToner}
                ranges={{
                  good: [0.3, Infinity],
                  average: [0.1, 0.3],
                  bad: [-Infinity, 0.1],
                }}
              >
                {toner}/{maxToner}
              </ProgressBar>
              {toner <= 0 && (
                <NoticeBox warning>
                  Insert a new toner cartridge to continue copying.
                </NoticeBox>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Section title="Print Job" fill>
              {printingActive ? (
                <Stack vertical>
                  <Stack.Item>
                    Copying {copiesCompleted} of {copiesTotal}...
                  </Stack.Item>
                  <Stack.Item>
                    <PrintProgress
                      startedAt={currentCopyStartedAt}
                      endsAt={currentCopyEndsAt}
                      worldTime={worldtime}
                    />
                  </Stack.Item>
                </Stack>
              ) : (
                <Stack vertical>
                  <Stack.Item>
                    <Stack align="center">
                      <Stack.Item>Copies:</Stack.Item>
                      <Stack.Item grow>
                        <NumberInput
                          fluid
                          value={copies}
                          minValue={1}
                          maxValue={maxcopies}
                          step={1}
                          onChange={(value) =>
                            act('set_copies', { copies: value })
                          }
                        />
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      fluid
                      icon="copy"
                      disabled={!loadedType || toner <= 0}
                      onClick={() => act('start_print')}
                    >
                      Print
                    </Button>
                  </Stack.Item>
                </Stack>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

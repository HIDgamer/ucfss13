import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, DmIcon, Input, Section, Stack } from '../components';
import { Table, TableCell, TableRow } from '../components/Table';
import { Window } from '../layouts';

type CrewRecord = {
  name: string;
  job: string;
  minutes_ago: number;
};

type ItemRecord = {
  name: string;
  ref: string;
  icon: string;
  icon_state: string;
};

type Data = {
  welcome_name: string;
  cryotype: string;
  frozen_crew: CrewRecord[];
  frozen_items: ItemRecord[];
};

export const CryopodConsole = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    welcome_name,
    cryotype,
    frozen_crew = [],
    frozen_items = [],
  } = data;
  const [searchTerm, setSearchTerm] = useState('');

  const filteredItems = frozen_items.filter((item) =>
    item.name.toLowerCase().includes(searchTerm.toLowerCase()),
  );

  return (
    <Window
      theme="weyland"
      title={`Cryogenic Oversight Control — ${cryotype}`}
      width={480}
      height={560}
    >
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Box color="label" fontStyle="italic">
              Welcome, {welcome_name}.
            </Box>
          </Stack.Item>

          <Stack.Item>
            <Section
              title="Stored Objects"
              buttons={
                <Button.Confirm
                  icon="boxes-stacked"
                  disabled={frozen_items.length === 0}
                  onClick={() => act('recover_all')}
                >
                  Recover All
                </Button.Confirm>
              }
            >
              <Stack vertical>
                <Stack.Item>
                  <Input
                    fluid
                    placeholder="Search stored objects..."
                    value={searchTerm}
                    onInput={(_, value) => setSearchTerm(value)}
                  />
                </Stack.Item>
                <Stack.Item>
                  {frozen_items.length === 0 ? (
                    <Box color="label" fontStyle="italic">
                      Nothing in storage.
                    </Box>
                  ) : filteredItems.length === 0 ? (
                    <Box color="label" fontStyle="italic">
                      No objects match your search.
                    </Box>
                  ) : (
                    <Table>
                      {filteredItems.map((item) => (
                        <TableRow key={item.ref}>
                          <TableCell collapsing>
                            <DmIcon
                              icon={item.icon}
                              icon_state={item.icon_state}
                              width="24px"
                            />
                          </TableCell>
                          <TableCell>{item.name}</TableCell>
                          <TableCell collapsing>
                            <Button
                              icon="box-open"
                              onClick={() =>
                                act('recover_item', { ref: item.ref })
                              }
                            >
                              Recover
                            </Button>
                          </TableCell>
                        </TableRow>
                      ))}
                    </Table>
                  )}
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section title="Recently Stored Crewmembers" fill>
              {frozen_crew.length === 0 ? (
                <Box color="label" fontStyle="italic">
                  No records.
                </Box>
              ) : (
                <Table>
                  {frozen_crew.map((person, i) => (
                    <TableRow key={i}>
                      <TableCell>{person.name}</TableCell>
                      <TableCell color="label">{person.job}</TableCell>
                      <TableCell collapsing color="label">
                        {person.minutes_ago <= 0
                          ? 'just now'
                          : `${person.minutes_ago}m ago`}
                      </TableCell>
                    </TableRow>
                  ))}
                </Table>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

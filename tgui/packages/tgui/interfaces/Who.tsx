import { ReactNode, useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Collapsible,
  Icon,
  Input,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';

type PlayerPayload = {
  readonly text: string;
  readonly ckey_color?: string;
  readonly color?: string;
};

type Entry<T> = Record<string, T[]>;

type FactionInfo = {
  readonly content: string;
  readonly color: string;
  readonly text: string;
};

type Data = {
  base_data?: {
    total_players: Entry<PlayerPayload>[];
  };
  player_additional?: {
    total_players: Entry<PlayerPayload>[];
  };
  player_stealthed_additional?: {
    total_players: Entry<PlayerPayload>[];
  };
  factions_additional?: FactionInfo[];
};

export const Who = () => {
  const { act, data } = useBackend<Data>();
  const {
    base_data,
    player_additional,
    player_stealthed_additional,
    factions_additional,
  } = data;

  const total_players = mergeArrays(
    base_data?.total_players,
    player_additional?.total_players,
    player_stealthed_additional?.total_players,
  );

  const [searchQuery, setSearchQuery] = useState('');

  const searchPlayers = () =>
    total_players.filter((playerObj) => isMatch(playerObj, searchQuery));

  const filteredTotalPlayers = searchPlayers();

  return (
    <Window resizable width={800} height={600}>
      <Window.Content scrollable>
        <Stack fill vertical>
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item>
                  <Icon name="search" />
                </Stack.Item>
                <Stack.Item grow>
                  <Input
                    autoFocus
                    fluid
                    onEnter={() => {
                      const clientObj = searchPlayers()?.[0];
                      if (!clientObj) return;
                      act('get_player_panel', {
                        ckey: Object.keys(clientObj)[0],
                      });
                    }}
                    onInput={(e, value) => setSearchQuery(value)}
                    placeholder="Search..."
                    value={searchQuery}
                  />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item mt={0.2} grow>
            {filteredTotalPlayers && (
              <Section>
                <WhoCollapsible
                  title={'Players - ' + filteredTotalPlayers.length}
                  color="good"
                >
                  <Box>
                    <FilterPlayers players_to_filter={filteredTotalPlayers} />
                  </Box>
                </WhoCollapsible>
              </Section>
            )}
            {factions_additional && (
              <Section>
                <WhoCollapsible title="Information" color="olive">
                  <Box>
                    {factions_additional.map((x, index) => (
                      <GetAddInfo
                        key={index}
                        content={x.content}
                        color={x.color}
                        text={x.text}
                      />
                    ))}
                  </Box>
                </WhoCollapsible>
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

type WhoCollapsibleProps = {
  readonly title: string;
  readonly color?: string;
  readonly children: ReactNode;
};

const WhoCollapsible = (props: WhoCollapsibleProps) => {
  const { title, color, children } = props;
  return (
    <Collapsible title={title} color={color} open>
      {children}
    </Collapsible>
  );
};

const GetAddInfo = (props: FactionInfo) => {
  const { content, color, text } = props;

  return (
    <Button
      color="transparent"
      style={{
        borderColor: color,
        borderStyle: 'solid',
        borderWidth: '1px',
        color: color,
      }}
      tooltip={text}
      tooltipPosition="bottom-start"
    >
      {content}
    </Button>
  );
};

const FilterPlayers = (props: {
  players_to_filter: Entry<PlayerPayload>[];
}) => {
  const { players_to_filter } = props;

  return players_to_filter.map((clientObj) => {
    const ckey = Object.keys(clientObj)[0];
    return <GetPlayerInfo key={ckey} ckey={ckey} {...clientObj[ckey][0]} />;
  });
};

const GetPlayerInfo = (props: PlayerPayload & { readonly ckey: string }) => {
  const { act } = useBackend<Data>();
  const { ckey, text, color, ckey_color } = props;

  return (
    <Button
      color="transparent"
      style={{
        borderColor: color || '#2185d0',
        borderStyle: 'solid',
        borderWidth: '1px',
        color: color || ckey_color || '#2185d0',
      }}
      onClick={() => act('get_player_panel', { ckey: ckey })}
      tooltip={text}
      tooltipPosition="bottom-start"
    >
      <div style={{ color: color || ckey_color || '#2185d0' }}>{ckey}</div>
    </Button>
  );
};

const isMatch = (playerObj: Entry<PlayerPayload>, searchQuery: string) => {
  if (!searchQuery) {
    return true;
  }

  const key = Object.keys(playerObj)[0];
  return key.toLowerCase().includes(searchQuery?.toLowerCase()) || false;
};

// Krill me please
const mergeArrays = (
  ...arrays: (Entry<PlayerPayload>[] | undefined)[]
): Entry<PlayerPayload>[] => {
  const mergedObject: Record<string, PlayerPayload[]> = {};

  arrays.forEach((array) => {
    if (!array) return;

    array.forEach((item) => {
      if (!item) return;

      const key = Object.keys(item)[0];
      const value = item[key];

      if (!mergedObject[key]) {
        mergedObject[key] = [];
      }

      value.forEach((subItem) => {
        if (typeof subItem !== 'object' || subItem === null) return;

        const existingItemIndex = mergedObject[key].findIndex(
          (existingSubItem) =>
            Object.keys(existingSubItem).some((subKey) =>
              Object.prototype.hasOwnProperty.call(subItem, subKey),
            ),
        );

        if (existingItemIndex !== -1) {
          mergedObject[key][existingItemIndex] = {
            ...mergedObject[key][existingItemIndex],
            ...subItem,
          };
        } else {
          mergedObject[key].push(subItem);
        }
      });
    });
  });

  return Object.keys(mergedObject).map((key) => ({ [key]: mergedObject[key] }));
};

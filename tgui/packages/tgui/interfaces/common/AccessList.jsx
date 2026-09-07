import { sortBy } from 'common/collections';
import { useState } from 'react';

import { Box, Button, Input, Section, Stack, Tabs } from '../../components';

const IFF_REGION_ID = 'Faction (IFF system)';

const diffMap = {
  0: {
    icon: 'times-circle',
    color: 'bad',
  },
  1: {
    icon: 'stop-circle',
    color: null,
  },
  2: {
    icon: 'check-circle',
    color: 'good',
  },
};

export const AccessList = (props) => {
  const {
    accesses = [],
    selectedList = [],
    accessMod,
    grantAll,
    denyAll,
    grantDep,
    denyDep,
  } = props;
  const [selectedAccessName, setSelectedAccessName] = useState(
    accesses[0]?.name,
  );
  const [search, setSearch] = useState('');
  const selectedAccess = accesses.find(
    (access) => access.name === selectedAccessName,
  );
  const selectedAccessEntries = sortBy(
    selectedAccess?.accesses || [],
    (entry) => entry.desc,
  ).filter((entry) => entry.desc.toLowerCase().includes(search.toLowerCase()));

  const countGranted = (accesses) =>
    accesses.filter((entry) => selectedList.includes(entry.ref)).length;

  const checkAccessIcon = (accesses) => {
    const granted = countGranted(accesses);
    if (granted === 0) {
      return 0;
    } else if (granted < accesses.length) {
      return 1;
    } else {
      return 2;
    }
  };

  return (
    <Section
      title="Access"
      buttons={
        <>
          <Button icon="check-double" color="good" onClick={() => grantAll()}>
            Grant All
          </Button>
          <Button.Confirm
            icon="undo"
            color="bad"
            confirmContent="Revoke every access and faction IFF from this card?"
            onClick={() => denyAll()}
          >
            Deny All
          </Button.Confirm>
        </>
      }
    >
      <Stack>
        <Stack.Item>
          <Tabs vertical>
            {accesses.map((access) => {
              const entries = access.accesses || [];
              const isIff = access.regid === IFF_REGION_ID;
              const icon = isIff
                ? 'flag'
                : diffMap[checkAccessIcon(entries)].icon;
              const color = isIff ? null : diffMap[checkAccessIcon(entries)].color;
              return (
                <Tabs.Tab
                  key={access.name}
                  altSelection
                  color={color}
                  icon={icon}
                  selected={access.name === selectedAccessName}
                  onClick={() => setSelectedAccessName(access.name)}
                >
                  {access.name}
                  {entries.length > 0 && (
                    <Box color="label" inline ml={1}>
                      ({countGranted(entries)}/{entries.length})
                    </Box>
                  )}
                </Tabs.Tab>
              );
            })}
          </Tabs>
        </Stack.Item>
        <Stack.Item grow>
          <Stack>
            <Stack.Item>
              <Button
                fluid
                icon="check"
                color="good"
                onClick={() => grantDep(selectedAccess.regid)}
              >
                Grant Region
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                fluid
                icon="times"
                color="bad"
                onClick={() => denyDep(selectedAccess.regid)}
              >
                Deny Region
              </Button>
            </Stack.Item>
          </Stack>
          <Input
            fluid
            mt={1}
            placeholder="Search access.."
            value={search}
            onInput={(e, value) => setSearch(value)}
          />
          <Stack vertical mt={1}>
            {selectedAccessEntries.map((entry) => (
              <Stack.Item key={entry.desc}>
                <Button.Checkbox
                  fluid
                  checked={selectedList.includes(entry.ref)}
                  onClick={() => accessMod(entry.ref)}
                >
                  {entry.desc}
                </Button.Checkbox>
              </Stack.Item>
            ))}
          </Stack>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

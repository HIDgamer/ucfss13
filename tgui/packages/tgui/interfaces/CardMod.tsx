import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Collapsible,
  Input,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from '../components';
import { Window } from '../layouts';
import { AccessList } from './common/AccessList';
import { PrintProgress } from './common/PrintProgress';

type Job = {
  display_name: string;
  job: string;
};

type AccessEntry = {
  desc: string;
  ref: number | string;
};

type Region = {
  name: string;
  regid: number | string;
  accesses: AccessEntry[];
};

type Data = {
  theme: string;
  authenticated: BooleanLike;
  notice_text: string | null;
  notice_severity: 'info' | 'danger';
  worldtime: number;
  printing: BooleanLike;
  print_started_at: number;
  print_ends_at: number;
  has_id: BooleanLike;
  id_name: string;
  id_rank?: string;
  id_owner?: string;
  access_on_card?: Array<number | string>;
  id_account?: number;
  modification_log?: string[];
  jobs: Record<string, Job[]>;
  regions: Region[];
};

export const CardMod = () => {
  const { data } = useBackend<Data>();

  return (
    <Window width={450} height={560} resizable theme={data.theme}>
      <Window.Content scrollable>
        <CardContent />
      </Window.Content>
    </Window>
  );
};

export const CardContent = () => {
  const { act, data } = useBackend<Data>();
  const [tab, setTab] = useState(1);
  const {
    authenticated,
    regions = [],
    access_on_card = [],
    jobs = {},
    id_rank,
    id_owner,
    has_id,
    id_name,
    id_account,
    notice_text,
    notice_severity,
    printing,
    print_started_at,
    print_ends_at,
    worldtime,
    modification_log = [],
  } = data;
  const [selectedDepartment, setSelectedDepartment] = useState(
    Object.keys(jobs)[0],
  );
  const [jobSearch, setJobSearch] = useState('');
  const departmentJobs = (jobs[selectedDepartment] || []).filter((job) =>
    job.display_name.toLowerCase().includes(jobSearch.toLowerCase()),
  );
  return (
    <>
      {!!notice_text && (
        <NoticeBox danger={notice_severity === 'danger'} info={notice_severity === 'info'}>
          {notice_text}
        </NoticeBox>
      )}
      <Section
        title={
          has_id && authenticated ? (
            <Input
              value={id_owner}
              width="250px"
              onInput={(e, value) =>
                act('PRG_edit', {
                  name: value,
                })
              }
            />
          ) : (
            id_owner || 'No Card Inserted'
          )
        }
        buttons={
          <>
            <Button
              icon="print"
              disabled={!has_id || !authenticated || !!printing}
              onClick={() =>
                act('PRG_print', {
                  mode: 1,
                })
              }
            >
              Print
            </Button>
            <Button
              icon={authenticated ? 'sign-out-alt' : 'sign-in-alt'}
              color={authenticated ? 'bad' : 'good'}
              onClick={() => {
                act(authenticated ? 'PRG_logout' : 'PRG_authenticate');
              }}
            >
              {authenticated ? 'Log Out' : 'Log In'}
            </Button>
          </>
        }
      >
        <Button fluid icon="eject" onClick={() => act('PRG_eject')}>
          {id_name}
        </Button>
        {!!printing && (
          <Box mt="0.25rem">
            <PrintProgress
              startedAt={print_started_at}
              endsAt={print_ends_at}
              worldTime={worldtime}
            >
              Printing Access Report..
            </PrintProgress>
          </Box>
        )}
        {!!has_id && !!authenticated && (
          <>
            Linked Account:
            <NumberInput
              value={id_account ?? 0}
              minValue={111111}
              maxValue={999999}
              width="60px"
              onChange={(value) =>
                act('PRG_account', {
                  account: value,
                })
              }
            />
          </>
        )}
      </Section>
      {!!has_id && !!authenticated && (
        <Box>
          <Tabs>
            <Tabs.Tab selected={tab === 1} onClick={() => setTab(1)}>
              Access
            </Tabs.Tab>
            <Tabs.Tab selected={tab === 2} onClick={() => setTab(2)}>
              Jobs
            </Tabs.Tab>
            <Tabs.Tab selected={tab === 3} onClick={() => setTab(3)}>
              History
            </Tabs.Tab>
          </Tabs>
          {tab === 1 && (
            <AccessList
              accesses={regions}
              selectedList={access_on_card}
              accessMod={(ref) =>
                act('PRG_access', {
                  access_target: ref,
                })
              }
              grantAll={() => act('PRG_grantall')}
              denyAll={() => act('PRG_denyall')}
              grantDep={(dep) =>
                act('PRG_grantregion', {
                  region: dep,
                })
              }
              denyDep={(dep) =>
                act('PRG_denyregion', {
                  region: dep,
                })
              }
            />
          )}
          {tab === 2 && (
            <Section
              title={id_rank}
              buttons={
                <Button.Confirm
                  icon="exclamation-triangle"
                  color="bad"
                  confirmContent="Terminate this ID? This wipes its assignment and all access."
                  onClick={() => act('PRG_terminate')}
                >
                  Terminate
                </Button.Confirm>
              }
            >
              <Button.Input
                fluid
                onCommit={(e, value) =>
                  act('PRG_assign', {
                    assign_target: 'Custom',
                    custom_name: value,
                  })
                }
              >
                Custom...
              </Button.Input>
              <Stack>
                <Stack.Item>
                  <Tabs vertical>
                    {Object.keys(jobs).map((department) => (
                      <Tabs.Tab
                        key={department}
                        selected={department === selectedDepartment}
                        onClick={() => setSelectedDepartment(department)}
                      >
                        {department}
                      </Tabs.Tab>
                    ))}
                  </Tabs>
                </Stack.Item>
                <Stack.Item grow={1}>
                  <Input
                    fluid
                    mb={1}
                    placeholder="Search jobs.."
                    value={jobSearch}
                    onInput={(e, value) => setJobSearch(value)}
                  />
                  {departmentJobs.map((job) => (
                    <Button.Confirm
                      fluid
                      key={job.job}
                      confirmContent={`Assign as ${job.display_name}? This replaces the card's current access with this job's default set.`}
                      onClick={() =>
                        act('PRG_assign', {
                          assign_target: job.job,
                        })
                      }
                    >
                      {job.display_name}
                    </Button.Confirm>
                  ))}
                </Stack.Item>
              </Stack>
            </Section>
          )}
          {tab === 3 && (
            <Section title="Modification Log">
              {modification_log.length === 0 ? (
                <Box color="label" fontStyle="italic">
                  No modifications recorded for this card yet.
                </Box>
              ) : (
                <Collapsible title={`${modification_log.length} entries`} open>
                  {modification_log.map((entry, index) => (
                    <Box key={index} mb="0.25rem">
                      {entry}
                    </Box>
                  ))}
                </Collapsible>
              )}
            </Section>
          )}
        </Box>
      )}
    </>
  );
};

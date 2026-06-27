/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { classes } from 'common/react';
import { useDispatch, useSelector } from 'tgui/backend';
import { Box, Button, Flex, Tabs } from 'tgui/components';

import { openChatSettings } from '../settings/actions';
import { selectSettings } from '../settings/selectors';
import { addChatPage, changeChatPage } from './actions';
import { selectChatPages, selectCurrentChatPage } from './selectors';

const UnreadCountWidget = ({ value }) => (
  <Box className="CrtChatTabs__unread">
    {Math.min(value, 99)}
  </Box>
);

export const ChatTabs = (props) => {
  const pages = useSelector(selectChatPages);
  const currentPage = useSelector(selectCurrentChatPage);
  const { theme } = useSelector(selectSettings);
  const dispatch = useDispatch();
  const isCrt = theme.startsWith('crt-');
  return (
    <Flex
      align="center"
      className={classes([isCrt && 'CrtChatTabs'])}
    >
      <Flex.Item>
        <Tabs textAlign="center">
          {pages.map((page) => (
            <Tabs.Tab
              key={page.id}
              selected={page === currentPage}
              rightSlot={
                !page.hideUnreadCount &&
                page.unreadCount > 0 && (
                  <UnreadCountWidget value={page.unreadCount} />
                )
              }
              onClick={() =>
                dispatch(
                  changeChatPage({
                    pageId: page.id,
                  }),
                )
              }
            >
              {page.name}
            </Tabs.Tab>
          ))}
        </Tabs>
      </Flex.Item>
      <Flex.Item ml={1}>
        <Button
          color="transparent"
          icon="plus"
          onClick={() => {
            dispatch(addChatPage());
            dispatch(openChatSettings());
          }}
        />
      </Flex.Item>
    </Flex>
  );
};

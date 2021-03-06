{
 this file is part of Ares
 Aresgalaxy ( http://aresgalaxy.sourceforge.net )

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*****************************************************************
 The following delphi code is based on Emule (0.46.2.26) Kad's implementation http://emule.sourceforge.net
 and KadC library http://kadc.sourceforge.net/
*****************************************************************
 }

{
Description:
DHT high level routines related to searches
}

unit dhtsearchManager;

interface

uses
 classes,classes2,int128,dhtconsts,dhttypes,dhtsearch,sysutils;

 procedure findNode(id:pCU_INT128);
 procedure findNodeComplete(id:pCU_Int128);
 function alreadySearchingFor(target:pCU_INT128):boolean;
 procedure processResponse(target:pCU_INT128; fromIP:cardinal; fromPort:word;
  results:tmylist; garbageList:TMylist);
 procedure CheckSearches(nowt:cardinal);//every second
 procedure PublishHash(phash:precord_DHT_hashfile);
 procedure processPublishHashAck(target:pCU_INT128; fromip:cardinal; fromporT:word);
 function num_searches(ttype:dhttypes.tdhtsearchtype):integer;
 procedure processPublishKeyAck(publishID:pCU_INT128; fromip:cardinal; fromPort:word);
 procedure SendPublishKeyFiles(s:TDHTSearch; TargetIP:cardinal; TargetPort:word);
 function has_KeywordSearchWithID(ID:word):boolean;
 procedure ClearContacts(list:TMylist);


implementation

uses
 vars_global,helper_datetime,
 windows,dhtSocket,mysupernodes,dhtcontact;




function has_KeywordSearchWithID(ID:word):boolean;
var
i:integer;
s:tDHTsearch;
begin
result:=false;

 for i:=0 to DHT_Searches.count-1 do begin
  s:=DHT_Searches[i];
  if s.m_type<>dhttypes.KEYWORD then continue;
  if s.m_searchID<>ID then continue;
   result:=true;
   exit;
 end;

end;


function num_searches(ttype:dhttypes.tdhtsearchtype):integer;
var
i:integer;
s:TDHTSearch;
begin
 result:=0;

 for i:=0 to DHT_Searches.count-1 do begin
  s:=DHT_Searches[i];
  if s.m_type=ttype then inc(result);
 end;

end;

procedure SendPublishKeyFiles(s:TDHTSearch; TargetIP:cardinal; TargetPort:word);
var
i,offset:integer;
lenItem:word;
payload:string;
begin
offset:=0;

for i:=0 to s.m_publishKeyPayloads.count-1 do begin

   if offset=0 then begin
     CU_INT128_CopyToBuffer(@s.m_target,@DHT_Buffer[2]);
     move(vars_global.myport,DHT_Buffer[18],2);
     inc(offset,20);
   end;

   payload:=s.m_publishKeyPayloads.strings[i];
   lenItem:=length(payload);
   move(lenItem,DHT_Buffer[offset],2);
    inc(offset,2);
   move(payload[1],DHT_Buffer[offset],lenItem);
    inc(offset,lenItem);

   if offset>=9000 then begin
    DHT_Len_tosend:=offset;
    DHT_Buffer[1]:=CMD_DHT_PUBLISHKEY_REQ;
    DHT_Send(TargetIP,TargetPort,True);
    offset:=0;
   end;
end;

if offset>20 then begin
 DHT_Len_tosend:=offset;
 DHT_Buffer[1]:=CMD_DHT_PUBLISHKEY_REQ;
 DHT_Send(TargetIP,TargetPort,(DHT_len_tosend>200));  
end;

end;

procedure PublishHash(phash:precord_DHT_hashfile);
var
s:tDHTsearch;
id:CU_INT128;

begin

CU_INT128_CopyFromBuffer(@phash^.hashValue[0],@id);
if alreadySearchingFor(@id) then exit;

	s:=TDHTsearch.create;
		s.m_type:=DHTtypes.STOREFILE;

		CU_INT128_Fill(@s.m_target,@id);
    setLength(s.m_outPayload,26);
		move(phash^.hashValue[0],s.m_outPayload[1],20);
    move(vars_global.LANIPC,s.m_outPayload[21],4);
    move(vars_global.myport,s.m_outPayload[25],2);

    // add up to 5 supernodes (len=30)
   if vars_global.im_firewalled then
    s.m_outPayload:=s.m_outPayload+mysupernodes.mysupernodes_serialize;


	DHT_Searches.add(s);
	 s.startIDSearch;
end;

procedure ClearContacts(list:TMylist);
var
c:TContact;
begin
while (list.count>0) do begin
 c:=list[list.count-1];
    list.delete(list.count-1);
 c.free;
end;
end;

procedure processResponse(target:pCU_INT128; fromIP:cardinal; fromPort:word;
 results:tmylist; garbageList:TMylist);
var
s:tDHTsearch;
i:integer;
found:boolean;
begin
 found:=false;
 s:=nil;
 
 for i:=0 to DHT_searches.count-1 do begin
  s:=DHT_searches[i];
  if CU_INT128_Compare(@s.m_target,target) then begin
   found:=true;
   break;
  end;
 end;

	if not found then begin
   ClearContacts(GarbageList);
   exit;
  end;

		s.processResponse(fromIP, fromPort, results);
end;


procedure processPublishKeyAck(publishID:pCU_INT128; fromip:cardinal; fromPort:word);
var
s:TDHTSearch;
i:integer;
begin

	for i:=0 to DHT_Searches.count-1 do begin
   s:=DHT_Searches[i];
   if s.m_type<>dhttypes.STOREKEYWORD then continue;
   if not CU_INT128_Compare(@s.m_target,publishID) then continue;

   inc(s.m_answers);
   break;
  end;

end;

procedure processPublishHashAck(target:pCU_INT128; fromip:cardinal; fromporT:word);
var
s:TDHTSearch;
i:integer;
begin

	for i:=0 to DHT_Searches.count-1 do begin
  s:=DHT_Searches[i];
  if s.m_type<>dhttypes.STOREFILE then continue;
  if CU_INT128_Compare(@s.m_target,target) then begin
   inc(s.m_answers);

   break;
  end;
 end;

end;



function alreadySearchingFor(target:pCU_INT128):boolean;
var
i:integer;
s:tDHTsearch;
begin
result:=False;

 for i:=0 to DHT_Searches.count-1 do begin
    s:=DHT_Searches[i];
    if CU_INT128_Compare(@s.m_target, target) then begin
     result:=true;
     exit;
    end;
 end;

end;

procedure findNodeComplete(id:pCU_Int128);
var
s:tDHTsearch;
begin
	if alreadySearchingFor(id) then exit;

	s:=TDHTsearch.create;
		s.m_type:=DHTtypes.NODECOMPLETE;
		CU_INT128_fill(@s.m_target,id);
		DHT_Searches.add(s);
	 s.startIDSearch;
end;

procedure findNode(id:pCU_INT128);
var
s:tDHTsearch;
begin
 if alreadySearchingFor(id) then exit;

	s:=TDHTsearch.create;
		s.m_type:=DHTtypes.NODE;
		CU_INT128_fill(@s.m_target,id);
		DHT_Searches.add(s);
	 s.StartIDSearch;
end;

procedure CheckSearches(nowt:cardinal);//every second
var
i:integer;
s:TDHTSearch;
begin

i:=0;
 while (i<DHT_Searches.count) do begin
   s:=DHT_Searches[i];

   case s.m_type of


		KEYWORD:begin
					if s.m_created+SEARCHKEYWORD_LIFETIME<nowt then begin
						DHT_Searches.delete(i);
            s.free;
            continue;
					end;

					if ((s.m_answers>=SEARCHKEYWORD_TOTAL) or
              (s.m_created+SEARCHKEYWORD_LIFETIME-SEC(20)<nowt)) then begin
						s.expire;
            inc(i);
            continue;
          end;
          s.CheckStatus;
			end;


			FINDSOURCE:begin
					if s.m_created+SEARCHFINDSOURCE_LIFETIME<nowt then begin
            DHT_Searches.delete(i);
            s.free;
            continue;
					end;

					if ((s.m_answers>=SEARCHFINDSOURCE_TOTAL) or
              (s.m_created+SEARCHFINDSOURCE_LIFETIME-SEC(20)<nowt)) then begin
             s.expire;
             inc(i);
             continue;
          end;

			    s.CheckStatus;
			end;

			NODE:begin
				if s.m_created+SEARCHNODE_LIFETIME<nowt then begin
            DHT_Searches.delete(i);
            s.free;
            continue;
				end;
        s.CheckStatus;
			end;

			NODECOMPLETE:begin
				if s.m_created+SEARCHNODE_LIFETIME<nowt then begin
						DHT_m_Publish:=true;
            DHT_Searches.delete(i);
            s.free;
            continue;
				end;

				if ((s.m_created+SEARCHNODECOMP_LIFETIME<nowt) and
            (s.m_answers>=SEARCHNODECOMP_TOTAL)) then begin
						DHT_m_Publish:=true;
            DHT_Searches.delete(i);
            s.free;
            continue;
					end;
        s.CheckStatus;

			end;

			STOREFILE:begin
				 if s.m_created+SEARCHSTOREFILE_LIFETIME<nowt then begin
            DHT_Searches.delete(i);
            s.free;
            continue;
				 end;

				if ((s.m_answers>=SEARCHSTOREFILE_TOTAL) or
            (s.m_created+SEARCHSTOREFILE_LIFETIME-SEC(20)<nowt)) then begin
						s.expire;
						inc(i);
            continue;
					end;

					s.CheckStatus;
				end;

				STOREKEYWORD:begin
				   if s.m_created+SEARCHSTOREKEYWORD_LIFETIME<nowt then begin
						DHT_Searches.delete(i);
            s.free;
            continue;
					 end;

					if ((s.m_answers>=SEARCHSTOREKEYWORD_TOTAL) or
              (s.m_created+SEARCHSTOREKEYWORD_LIFETIME-SEC(20)<nowt)) then begin
						s.expire;
						inc(i);
            continue;
					end;

					s.CheckStatus;
          
        end else begin
					if s.m_created+SEARCH_LIFETIME<nowt then begin
					  DHT_Searches.delete(i);
            s.free;
            continue;
					end;

					s.CheckStatus;
        end;
    end;

  inc(i);
 end;

end;


end.
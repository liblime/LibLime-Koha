--
-- Default account types and descriptions for Koha.
--
-- Copyright (C) 2008 LiblimeA
--
-- This file is part of Koha.
--
-- Koha is free software; you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 2 of the License, or (at your option) any later
-- version.
-- 
-- Koha is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
-- A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License along with
-- Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
-- Suite 330, Boston, MA  02111-1307 USA

-- account types
INSERT INTO `accounttypes` (`code`, `description`, `class`)
        VALUES
        ('ACCTMANAGE','Account Management Fee','fee'),
        ('FINE','Overdue Fine','fee'),
        ('LOSTITEM','Lost Item','fee'),
        ('NEWCARD','New Card Issued','fee'),
        ('RENEWCARD','Renew Patron Account','fee'),
        ('RESERVE','Hold Placed','fee'),
        ('REFUND','Refund','fee'),
        ('REVERSED_PAYMENT','Reversed Payment','fee'),
        ('RENTAL','Checkout fee','fee'),
        ('EXPIRED_HOLD','Expired Hold fee','fee'),
        ('COLLECTIONS','Collections Agency Fee','fee'),
        ('CANCELCREDIT','Credit Canceled','fee'),
        ('SUNDRY','Sundry','invoice'),
        ('FORGIVE','Fine Forgiven','transaction'),
        ('WRITEOFF','Writeoff','transaction'),
        ('LOSTRETURNED','Lost, Returned', 'transaction'),
        ('CLAIMS_RETURNED','Claims Returned', 'transaction'),
        ('OVERDUE_LOST','Overdue fees waived on lost item', 'transaction'),
        ('SYSTEM_CREDIT','System-mediated credit','transaction'),
        ('SYSTEM_DEBIT','System-mediated debit','fee'),
        ('PAYMENT','Payment','payment'),
        ('CREDIT','Credit','payment'),
        ('TRANSBUS','Transferred to Business Office','payment')
;

